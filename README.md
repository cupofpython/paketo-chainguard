# Hello World Java + Paketo + Chainguard

A minimal Java "hello world" that is:

1. Compiled into an executable JAR with Maven.
2. Packaged into a container image by **Paketo Buildpacks** via the **`pack`** CLI
   (the JAR is layered on top of a Paketo run image — no `Dockerfile` for the app).
3. Re-packaged onto a **Chainguard** run image (`cgr.dev/chainguard/...`) for a
   minimal, low-CVE runtime.

```
.
├── pom.xml                         # Maven build → target/hello-world.jar
├── src/main/java/dev/chainguard/example/HelloWorld.java
└── run-image/Dockerfile            # Chainguard-based Paketo run image
```

## Prerequisites

- JDK 21+ and Maven (`mvn -v`)
- Docker (or another CNB-compatible daemon)
- The `pack` CLI — **not currently installed on this machine**. Install with:
  ```bash
  brew install buildpacks/tap/pack
  ```

---

## Step 1 — Build the executable JAR

```bash
mvn package
```

This produces `target/hello-world.jar`. The `maven-jar-plugin` writes a
`Main-Class` into the manifest, which is what makes Paketo's **Executable JAR**
buildpack detect and run it.

Sanity check it locally:

```bash
java -jar target/hello-world.jar
# Hello, world! Running on OpenJDK 64-Bit Server VM 21...
```

---

## Step 2 — Layer the JAR onto Paketo with `pack`

Point `pack build --path` **at the JAR file itself** (not the source dir). Paketo
skips the "build from source" flow, contributes a JRE layer, and layers your JAR
on top of its run image:

```bash
pack build hello-java \
  --path target/hello-world.jar \
  --builder paketobuildpacks/builder-jammy-base \
  --env BP_JVM_VERSION=21
```

Run it:

```bash
docker run --rm hello-java
```

> `BP_JVM_VERSION=21` pins the JRE to the bytecode version compiled in `pom.xml`.

---

## Step 3 — Use a Chainguard base (run image) with Paketo

Paketo builders ship their own Ubuntu-based run image. You can swap it for a
Chainguard run image so the final image carries Chainguard's minimal,
continuously-patched userspace while still being built by Paketo.

A Chainguard base needs two things to satisfy the CNB run-image contract: a
matching stack-id label and a non-root user. `cgr.dev/chainguard/jre` already
runs as a non-root user, so the only thing missing is the `io.buildpacks.stack.id`
label. There are two ways to add it.

### 3a. No Dockerfile — stamp the label with `crane` (recommended)

You don't need a Dockerfile. `crane mutate` rewrites only the image config to add
the label and reuses the original layers — no `docker build`:

```bash
brew install crane   # or run cgr.dev/chainguard/crane

crane mutate cgr.dev/chainguard/jre:latest \
  --label io.buildpacks.stack.id=io.buildpacks.stacks.jammy \
  --label io.buildpacks.stack.mixins='[]' \
  -t hello-java-cg-run:latest \
  -o /tmp/cg-run.tar
docker load < /tmp/cg-run.tar
```

(The helper `run-image/mutate-run-image.sh` wraps this, including a variant that
pushes to a registry instead of the local daemon.)

> Note: you can't skip this and point `--run-image` at the pristine
> `cgr.dev/chainguard/jre:latest` — Paketo's lifecycle rejects a run image that
> has no `io.buildpacks.stack.id`. The mutate just stamps that one label; it is
> not a rebuild.

### 3b. With a Dockerfile

If you prefer a declarative file (e.g. to also install extra packages),
`run-image/Dockerfile` does the same thing:

```bash
docker build -t hello-java-cg-run:latest run-image/
```

### Build the app, swapping in the Chainguard run image

Either way, you now have `hello-java-cg-run:latest`:

```bash
pack build hello-java-cg \
  --path target/hello-world.jar \
  --builder paketobuildpacks/builder-jammy-base \
  --run-image hello-java-cg-run:latest \
  --pull-policy if-not-present \
  --env BP_JVM_VERSION=21
```

Run it:

```bash
docker run --rm hello-java-cg
```

Inspect the stack / base to confirm the Chainguard run image was used:

```bash
pack inspect-image hello-java-cg
```

### Caveats (be aware — these are real)

- **Stack label is a declaration, not a guarantee.** We label the Wolfi-based
  Chainguard image as `io.buildpacks.stacks.jammy` so the lifecycle accepts it.
  Both are glibc, and Paketo contributes its own BellSoft Liberica JRE as a
  layer, so a headless app like this works — but you are mixing a Jammy-targeted
  JRE layer onto a Wolfi userspace, so test anything that touches native libs
  (fonts/AWT, compression, TLS) before shipping.
- The `cgr.dev/chainguard/jre` base already contains a JRE; Paketo adds its own
  on top. If you want to avoid the duplicate, base `run-image/Dockerfile` on a
  smaller Chainguard image (e.g. `cgr.dev/chainguard/glibc-dynamic`) and verify
  the Liberica JRE's native deps (notably `libz`) are present.

### Alternative: rebase an already-built image

If you already built `hello-java` in Step 2, you can re-point it at the
Chainguard run image without rebuilding, as long as the run images are
compatible:

```bash
pack rebase hello-java --run-image hello-java-cg-run:latest
```

---

## Why Chainguard here

`cgr.dev/chainguard/jre` is a minimal, distroless, continuously-rebuilt JRE image
with a low/zero-CVE posture — a stronger runtime base than the default
general-purpose Ubuntu run image, while keeping the full Paketo build experience.

## References

- [Paketo — How to Build Java Apps](https://paketo.io/docs/howto/java/)
- [Paketo — Java Buildpack Reference](https://paketo.io/docs/reference/java-reference/)
- [Paketo — Create a Custom Stack (run image labels)](https://paketo.io/docs/howto/create-custom-stack/)
- [Paketo — Stacks concept](https://paketo.io/docs/concepts/stacks/)
- [Chainguard Images directory](https://images.chainguard.dev/)

package dev.chainguard.example;

public class HelloWorld {
    public static void main(String[] args) {
        System.out.println("Hello, world! Running on " + System.getProperty("java.vm.name")
                + " " + System.getProperty("java.version"));
    }
}

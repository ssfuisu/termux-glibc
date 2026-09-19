package com.termux.glibc;

import android.os.Build;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Runs glibc binaries natively inside the Termux fork without proot or
 * any virtualization.
 *
 * <p>Android and glibc share the Linux kernel syscall ABI, so a glibc
 * sysroot installed next to the normal bionic $PREFIX just works. This
 * class executes every glibc binary directly through its own dynamic
 * loader (ld-linux) with LD_LIBRARY_PATH scoped to the glibc prefix.
 *
 * <p>Layout (filesDir is the app private files dir):
 * <ul>
 *   <li>bionic prefix: filesDir/usr (owned by Termux bootstrap, untouched)</li>
 *   <li>glibc sysroot: filesDir/usr/glibc (owned by GlibcInstaller)</li>
 * </ul>
 */
public final class GlibcRunner {

    private final File prefix;
    private final File glibcPrefix;

    public GlibcRunner(File filesDir) {
        this.prefix = new File(filesDir, "usr");
        this.glibcPrefix = new File(prefix, "glibc");
    }

    public File getPrefix() {
        return prefix;
    }

    public File getGlibcPrefix() {
        return glibcPrefix;
    }

    /** Returns arm64-v8a or armeabi-v7a for the current device. */
    public static String currentAbi() {
        for (String abi : Build.SUPPORTED_ABIS) {
            if ("arm64-v8a".equals(abi) || "armeabi-v7a".equals(abi)) {
                return abi;
            }
        }
        return Build.SUPPORTED_ABIS.length > 0 ? Build.SUPPORTED_ABIS[0] : "arm64-v8a";
    }

    public static boolean is64Bit() {
        return "arm64-v8a".equals(currentAbi());
    }

    /** Absolute path of the glibc dynamic loader for this device. */
    public File loader() {
        if (is64Bit()) {
            return new File(glibcPrefix, "lib/ld-linux-aarch64.so.1");
        }
        return new File(glibcPrefix, "lib/ld-linux-armhf.so.3");
    }

    /** Environment for glibc child processes. */
    public Map<String, String> environment() {
        Map<String, String> env = new HashMap<>(System.getenv());
        String libPath = new File(glibcPrefix, "lib").getAbsolutePath()
                + ":" + new File(glibcPrefix, "usr/lib").getAbsolutePath();
        env.put("LD_LIBRARY_PATH", libPath);
        env.put("PREFIX", prefix.getAbsolutePath());
        env.put("GLIBC_PREFIX", glibcPrefix.getAbsolutePath());
        env.put("LANG", "C.UTF-8");
        env.put("LC_ALL", "C.UTF-8");
        env.put("SSL_CERT_FILE", new File(prefix, "etc/tls/cert.pem").getAbsolutePath());
        env.put("PATH", glibcPrefix.getAbsolutePath() + "/bin:"
                + glibcPrefix.getAbsolutePath() + "/usr/bin:"
                + prefix.getAbsolutePath() + "/bin:/system/bin");
        env.put("TMPDIR", new File(prefix, "tmp").getAbsolutePath());
        return env;
    }

    /**
     * Build the argv used to exec a glibc binary:
     * ld-linux --library-path ... &lt;binary&gt; [args...]
     */
    public List<String> buildCommand(String glibcBinaryAbsolutePath, String... args) {
        File ld = loader();
        String libPath = new File(glibcPrefix, "lib").getAbsolutePath()
                + ":" + new File(glibcPrefix, "usr/lib").getAbsolutePath();
        List<String> cmd = new ArrayList<>();
        cmd.add(ld.getAbsolutePath());
        cmd.add("--library-path");
        cmd.add(libPath);
        cmd.add(glibcBinaryAbsolutePath);
        for (String a : args) {
            cmd.add(a);
        }
        return cmd;
    }

    /** glibc bash login shell argv. */
    public List<String> loginShell() {
        File bash = new File(glibcPrefix, "bin/bash");
        return buildCommand(bash.getAbsolutePath(), "--login");
    }

    public boolean isInstalled() {
        return loader().isFile()
                && new File(glibcPrefix, "bin/bash").isFile()
                && new File(glibcPrefix, ".glibc-bootstrap-done").isFile();
    }
}

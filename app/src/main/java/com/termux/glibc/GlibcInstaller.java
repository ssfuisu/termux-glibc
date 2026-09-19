package com.termux.glibc;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Installs the glibc sysroot next to the normal Termux bionic prefix.
 *
 * <p>The bootstrap zip is produced in CI by glibc/build.sh plus
 * scripts/make-bootstrap.sh and published as a release asset
 * (glibc-bootstrap-aarch64.zip / glibc-bootstrap-arm.zip). The normal
 * Termux bootstrap is left untouched, so the app always boots even
 * before glibc is installed.
 */
public final class GlibcInstaller {

    public interface Listener {
        void onLog(String line);
    }

    private final File filesDir;

    public GlibcInstaller(File filesDir) {
        this.filesDir = filesDir;
    }

    /** Download a bootstrap zip from a URL and extract it. */
    public void installFromUrl(String url, Listener listener) throws IOException {
        listener.onLog("Downloading glibc bootstrap: " + url);
        HttpURLConnection conn = (HttpURLConnection) new URL(url).openConnection();
        conn.setConnectTimeout(30000);
        conn.setReadTimeout(120000);
        conn.connect();
        if (conn.getResponseCode() != 200) {
            throw new IOException("HTTP " + conn.getResponseCode() + " for " + url);
        }
        try (InputStream in = new BufferedInputStream(conn.getInputStream())) {
            extractZip(in, listener);
        } finally {
            conn.disconnect();
        }
    }

    private void extractZip(InputStream in, Listener listener) throws IOException {
        File usr = new File(filesDir, "usr");
        if (!usr.isDirectory() && !usr.mkdirs()) {
            throw new IOException("Cannot create " + usr);
        }
        byte[] buf = new byte[65536];
        int count = 0;
        try (ZipInputStream zip = new ZipInputStream(in)) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                File out = new File(filesDir, entry.getName());
                if (entry.isDirectory()) {
                    out.mkdirs();
                } else {
                    File parent = out.getParentFile();
                    if (parent != null) {
                        parent.mkdirs();
                    }
                    try (OutputStream fout = new FileOutputStream(out)) {
                        int n;
                        while ((n = zip.read(buf)) > 0) {
                            fout.write(buf, 0, n);
                        }
                    }
                    if (entry.getName().contains("/bin/")
                            || entry.getName().contains("ld-linux")) {
                        out.setExecutable(true);
                    }
                }
                zip.closeEntry();
                count++;
                if (count % 200 == 0) {
                    listener.onLog("Extracted " + count + " entries...");
                }
            }
        }

        GlibcRunner runner = new GlibcRunner(filesDir);
        runner.loader().setExecutable(true);
        new File(runner.getGlibcPrefix(), "bin/bash").setExecutable(true);

        ensureResolvConf(listener);
        new File(usr, "tmp").mkdirs();
        File marker = new File(runner.getGlibcPrefix(), ".glibc-bootstrap-done");
        if (!marker.createNewFile() && !marker.exists()) {
            throw new IOException("Cannot write marker " + marker);
        }
        listener.onLog("glibc bootstrap done: " + count + " entries.");
    }

    private void ensureResolvConf(Listener listener) {
        File etc = new File(filesDir, "usr/glibc/etc");
        etc.mkdirs();
        File resolv = new File(etc, "resolv.conf");
        if (!resolv.exists()) {
            try (FileOutputStream out = new FileOutputStream(resolv)) {
                out.write("nameserver 1.1.1.1\nnameserver 8.8.8.8\n".getBytes());
                listener.onLog("Wrote default resolv.conf");
            } catch (IOException e) {
                listener.onLog("resolv.conf write failed: " + e.getMessage());
            }
        }
    }
}

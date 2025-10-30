Description: Debian settings for TeXMF tree.
Author: Hilmar Preuße <hille42@web.de>
Forwarded: not-needed
Last-Update: 2025-10-30

--- context.orig/texmf-dist/web2c/texmfcnf.lua
+++ context/texmf-dist/web2c/texmfcnf.lua
@@ -81,14 +81,16 @@
     comment = "ConTeXt MkIV and LMTX configuration file",
     author  = "Hans Hagen & Max Chernoff",
     target  = "texlive",
+    -- adaption by Preining Norbert / Hilmar Preuße for the Debian system
 
     content = {
         variables = {
             -- System trees
-            TEXMFDIST      = distribution,
-            TEXMFLOCAL     = system_data,
-            TEXMFSYSCONFIG = system_cache .. "/texmf-config",
-            TEXMFSYSVAR    = system_cache .. "/texmf-var",
+            TEXMFDIST      = "/usr/share/texlive/texmf-dist",
+            TEXMFLOCAL     = "/usr/local/share/texmf",
+            TEXMFDEBIAN    = "/usr/share/texmf",
+            TEXMFSYSCONFIG = "/etc/texmf",
+            TEXMFSYSVAR    = system_cache .. "/var/lib/texmf",
 
             -- User trees
             TEXMFCONFIG = user_cache .. "/texmf-config",
@@ -103,6 +105,7 @@
                               !!$TEXMFSYSCONFIG,\z
                               !!$TEXMFSYSVAR,\z
                               !!$TEXMFLOCAL,\z
+                              !!$TEXMFDEBIAN,\z
                               !!$TEXMFDIST\z
                           }",
 

termkit-deepseek for Windows
============================

Kimi Code with the termkit features, using only direct APIs: 7api,
CloseRouter and OpenRouter (no forwarders). The default model is
DeepSeek V4 Pro through 7api (through CloseRouter if you have no 7api key).

Install or update
-----------------
1. Extract this zip (right-click > Extract All...).
2. Double-click "Install.cmd".
3. Paste your 7api, CloseRouter and OpenRouter keys when asked. Press Enter
   on an empty line to skip any of them.
4. Open a NEW terminal, go to your project folder and type:  kimi

Or skip the download and paste this one line into PowerShell:

  [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/elisahuda6184-create/termkit-deepseek/main/install.ps1 | iex

No admin rights or Node.js needed. kimi.exe goes to
%LOCALAPPDATA%\Programs\termkit-deepseek and is added to your PATH. The keys
are saved as your user environment variables SEVENAPI_API_KEY,
CLOSEROUTER_API_KEY and OPENROUTER_API_KEY. Settings live in
%USERPROFILE%\.kimi-code (an existing config.toml is kept).

To change or remove a key later, run "Install.cmd" again
(Enter keeps a saved key, "-" removes it).

Kimi's built-in auto-update is turned off, because it would replace this
build with the plain official release. Never run "kimi upgrade" or
"npm install -g @moonshot-ai/kimi-code"; install a newer termkit-deepseek
instead.

Uninstall
---------
Double-click "Uninstall.cmd", or use Settings > Apps >
Installed apps > "termkit-deepseek".

Windows may warn that the files come from the internet or that kimi.exe is
from an unknown publisher (it is not code-signed). Choose "Run" / "More info >
Run anyway".

Kimi Code is MIT licensed by Moonshot AI, see LICENSE-upstream.txt.

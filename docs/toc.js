// Populate the sidebar
//
// This is a script, and not included directly in the page, to control the total size of the book.
// The TOC contains an entry for each page, so if each page includes a copy of the TOC,
// the total size of the page becomes O(n**2).
class MDBookSidebarScrollbox extends HTMLElement {
    constructor() {
        super();
    }
    connectedCallback() {
        this.innerHTML = '<ol class="chapter"><li class="chapter-item "><a href="index.html">Home</a></li><li class="chapter-item affix "><li class="part-title">src</li><li class="chapter-item "><a href="src/custom-tokens/index.html">❱ custom-tokens</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/custom-tokens/WETH/index.html">❱ WETH</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/custom-tokens/WETH/WETH.sol/contract.WETH.html">WETH</a></li><li class="chapter-item "><a href="src/custom-tokens/WETH/WETHNativeConverter.sol/contract.WETHNativeConverter.html">WETHNativeConverter</a></li></ol></li><li class="chapter-item "><a href="src/custom-tokens/GenericCustomToken.sol/contract.GenericCustomToken.html">GenericCustomToken</a></li><li class="chapter-item "><a href="src/custom-tokens/GenericNativeConverter.sol/contract.GenericNativeConverter.html">GenericNativeConverter</a></li></ol></li><li class="chapter-item "><a href="src/etc/index.html">❱ etc</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/etc/ERC20PermitUser.sol/abstract.ERC20PermitUser.html">ERC20PermitUser</a></li><li class="chapter-item "><a href="src/etc/IBridgeMessageReceiver.sol/interface.IBridgeMessageReceiver.html">IBridgeMessageReceiver</a></li><li class="chapter-item "><a href="src/etc/ILxLyBridge.sol/interface.ILxLyBridge.html">ILxLyBridge</a></li><li class="chapter-item "><a href="src/etc/IVaultBridgeTokenInitializer.sol/interface.IVaultBridgeTokenInitializer.html">IVaultBridgeTokenInitializer</a></li><li class="chapter-item "><a href="src/etc/IWETH9.sol/interface.IWETH9.html">IWETH9</a></li><li class="chapter-item "><a href="src/etc/Versioned.sol/abstract.Versioned.html">Versioned</a></li></ol></li><li class="chapter-item "><a href="src/vault-bridge-tokens/index.html">❱ vault-bridge-tokens</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/vault-bridge-tokens/vbETH/index.html">❱ vbETH</a><a class="toggle"><div>❱</div></a></li><li><ol class="section"><li class="chapter-item "><a href="src/vault-bridge-tokens/vbETH/VbETH.sol/contract.VbETH.html">VbETH</a></li></ol></li><li class="chapter-item "><a href="src/vault-bridge-tokens/GenericVaultBridgeToken.sol/contract.GenericVaultBridgeToken.html">GenericVaultBridgeToken</a></li></ol></li><li class="chapter-item "><a href="src/CustomToken.sol/abstract.CustomToken.html">CustomToken</a></li><li class="chapter-item "><a href="src/MigrationManager.sol/contract.MigrationManager.html">MigrationManager</a></li><li class="chapter-item "><a href="src/NativeConverter.sol/abstract.NativeConverter.html">NativeConverter</a></li><li class="chapter-item "><a href="src/VaultBridgeToken.sol/abstract.VaultBridgeToken.html">VaultBridgeToken</a></li><li class="chapter-item "><a href="src/VaultBridgeTokenInitializer.sol/contract.VaultBridgeTokenInitializer.html">VaultBridgeTokenInitializer</a></li><li class="chapter-item "><a href="src/VaultBridgeTokenPart2.sol/contract.VaultBridgeTokenPart2.html">VaultBridgeTokenPart2</a></li></ol>';
        // Set the current, active page, and reveal it if it's hidden
        let current_page = document.location.href.toString().split("#")[0];
        if (current_page.endsWith("/")) {
            current_page += "index.html";
        }
        var links = Array.prototype.slice.call(this.querySelectorAll("a"));
        var l = links.length;
        for (var i = 0; i < l; ++i) {
            var link = links[i];
            var href = link.getAttribute("href");
            if (href && !href.startsWith("#") && !/^(?:[a-z+]+:)?\/\//.test(href)) {
                link.href = path_to_root + href;
            }
            // The "index" page is supposed to alias the first chapter in the book.
            if (link.href === current_page || (i === 0 && path_to_root === "" && current_page.endsWith("/index.html"))) {
                link.classList.add("active");
                var parent = link.parentElement;
                if (parent && parent.classList.contains("chapter-item")) {
                    parent.classList.add("expanded");
                }
                while (parent) {
                    if (parent.tagName === "LI" && parent.previousElementSibling) {
                        if (parent.previousElementSibling.classList.contains("chapter-item")) {
                            parent.previousElementSibling.classList.add("expanded");
                        }
                    }
                    parent = parent.parentElement;
                }
            }
        }
        // Track and set sidebar scroll position
        this.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
                sessionStorage.setItem('sidebar-scroll', this.scrollTop);
            }
        }, { passive: true });
        var sidebarScrollTop = sessionStorage.getItem('sidebar-scroll');
        sessionStorage.removeItem('sidebar-scroll');
        if (sidebarScrollTop) {
            // preserve sidebar scroll position when navigating via links within sidebar
            this.scrollTop = sidebarScrollTop;
        } else {
            // scroll sidebar to current active section when navigating via "next/previous chapter" buttons
            var activeSection = document.querySelector('#sidebar .active');
            if (activeSection) {
                activeSection.scrollIntoView({ block: 'center' });
            }
        }
        // Toggle buttons
        var sidebarAnchorToggles = document.querySelectorAll('#sidebar a.toggle');
        function toggleSection(ev) {
            ev.currentTarget.parentElement.classList.toggle('expanded');
        }
        Array.from(sidebarAnchorToggles).forEach(function (el) {
            el.addEventListener('click', toggleSection);
        });
    }
}
window.customElements.define("mdbook-sidebar-scrollbox", MDBookSidebarScrollbox);

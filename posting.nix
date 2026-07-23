{ pkgs, ... }:

let
  python = pkgs.python313Packages;

  buildTreeSitterGrammar =
    {
      pname,
      version,
      arm64,
      x86_64,
    }:
    let
      wheel = if pkgs.stdenv.hostPlatform.isAarch64 then arm64 else x86_64;
    in
    python.buildPythonPackage {
      inherit pname version;
      format = "wheel";

      src = pkgs.fetchurl {
        inherit (wheel) url hash;
      };

      dependencies = [ python.tree-sitter ];
      doCheck = false;
    };

  tree-sitter-css = buildTreeSitterGrammar {
    pname = "tree-sitter-css";
    version = "0.25.0";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/4d/28/ebcbcbba812d3e407f2f393747330eb8843e0c69d159024e33460b622aab/tree_sitter_css-0.25.0-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-Wiqch1A371+dpXaX+4B1CGR21CpJ0lqI3Mpg38Cb0JI=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/25/a9/69e556f15ca774638bd79005369213dfbd41995bf032ce81cf3ffe086b8a/tree_sitter_css-0.25.0-cp310-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-3c5vhO6wuyh3tFh7B7/7B1MEDETYEe2asq+XjDE77ag=";
    };
  };

  tree-sitter-go = buildTreeSitterGrammar {
    pname = "tree-sitter-go";
    version = "0.25.0";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/32/16/dd4cb124b35e99239ab3624225da07d4cb8da4d8564ed81d03fcb3a6ba9f/tree_sitter_go-0.25.0-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-UDuBorTDHjAoaaHeOjUq0JEsyrPfmsmVAZewqc7qvY8=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/ca/aa/0984707acc2b9bb461fe4a41e7e0fc5b2b1e245c32820f0c83b3c602957c/tree_sitter_go-0.25.0-cp310-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-uFKZMGOjQppEPnvQqjdt190ynVlYGfq/VqxM+dcle1Q=";
    };
  };

  tree-sitter-java = buildTreeSitterGrammar {
    pname = "tree-sitter-java";
    version = "0.23.5";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/57/ef/6406b444e2a93bc72a04e802f4107e9ecf04b8de4a5528830726d210599c/tree_sitter_java-0.23.5-cp39-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-JKzVnEcg3trYDVSP5CN+Q+8rek6UyFSbDKbkxNe/bmk=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/67/21/b3399780b440e1567a11d384d0ebb1aea9b642d0d98becf30fa55c0e3a3b/tree_sitter_java-0.23.5-cp39-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-NVzgMIZy1vcBPskT3uSgYTZm9M2pBEp4JCQNF/OCCd8=";
    };
  };

  tree-sitter-regex = buildTreeSitterGrammar {
    pname = "tree-sitter-regex";
    version = "0.25.0";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/71/06/6b4f995f61952572a94bcfce12d43fc580226551fab9dd0aac4e94465f38/tree_sitter_regex-0.25.0-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-31cTZJuJxXWGSTmAU8MGxBVl8ipvJny17CVZZQS88BI=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/2b/b4/12e9ba02bab4ce13d1875f6585c3f2a5816233104d1507ea118950a4f7eb/tree_sitter_regex-0.25.0-cp310-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-P6EbvXaymsjKLb+FrQgvmxiuY1IlHYBestQZHhcGqdU=";
    };
  };

  tree-sitter-toml = buildTreeSitterGrammar {
    pname = "tree-sitter-toml";
    version = "0.7.0";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/92/20/ac8a20805339105fe0bbb6beaa99dbbd1159647760ddd786142364e0b7f2/tree_sitter_toml-0.7.0-cp39-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-GL4JU46Xdc3cApA5LE4nOd4iASYK82FHPKYLXCH3vSI=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/ad/4d/1e00a5cd8dba09e340b25aa60a3eaeae584ff5bc5d93b0777169d6741ee5/tree_sitter_toml-0.7.0-cp39-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-ua5cPnxba7BSmd1zRSzq+n+gaH1a8wEjMq+ndXZTtnY=";
    };
  };

  tree-sitter-xml = buildTreeSitterGrammar {
    pname = "tree-sitter-xml";
    version = "0.7.0";
    arm64 = {
      url = "https://files.pythonhosted.org/packages/75/f5/31013d04c4e3b9a55e90168cc222a601c84235ba4953a5a06b5cdf8353c4/tree_sitter_xml-0.7.0-cp39-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-BnT99Mw4bk0yPLKH07ByZj3g8gqemvXV4JghquVqnlw=";
    };
    x86_64 = {
      url = "https://files.pythonhosted.org/packages/36/1d/6b8974c493973c0c9df2bbf220a1f0a96fa785da81a5a13461faafd1441c/tree_sitter_xml-0.7.0-cp39-abi3-macosx_10_9_x86_64.whl";
      hash = "sha256-zD5RbUweCGD7IhcsFyFI3ruCW6Y4lxvEi60Vsi5bC64=";
    };
  };

  textualSyntaxDependencies = with python; [
    tree-sitter
    tree-sitter-bash
    tree-sitter-css
    tree-sitter-go
    tree-sitter-html
    tree-sitter-java
    tree-sitter-javascript
    tree-sitter-json
    tree-sitter-markdown
    tree-sitter-python
    tree-sitter-regex
    tree-sitter-rust
    tree-sitter-sql
    tree-sitter-toml
    tree-sitter-xml
    tree-sitter-yaml
  ];

  textual = python.buildPythonPackage rec {
    pname = "textual";
    version = "6.1.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-zImCbKIUbGRVYyWTIMpN3HXRg8d6+31YrN1GhJ35FE0=";
    };

    build-system = [ python.poetry-core ];
    dependencies = with python; [
      linkify-it-py
      markdown-it-py
      mdit-py-plugins
      platformdirs
      pygments
      rich
      typing-extensions
    ] ++ textualSyntaxDependencies;
    doCheck = false;
  };

  textual-autocomplete = python.buildPythonPackage {
    pname = "textual-autocomplete";
    version = "4.0.6";
    pyproject = true;

    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/1e/3a/80411bc7b94969eb116ad1b18db90f8dce8a1de441278c4a81fee55a27ca/textual_autocomplete-4.0.6.tar.gz";
      hash = "sha256-K6Lw12e+RIDsrLPksTDPBzQOAzw1APxCT+2RJdJ6RYY=";
    };

    build-system = [ python.hatchling ];
    dependencies = [
      textual
      python.typing-extensions
    ];
    doCheck = false;
  };

  posting = python.buildPythonApplication {
    pname = "posting";
    version = "2.10.0";
    pyproject = true;

    src = pkgs.fetchFromGitHub {
      owner = "wahh-22";
      repo = "posting";
      rev = "56703a11513e8e74e681b4f859f31945b71e746f";
      hash = "sha256-4L/MfXd6JYk2Viam9/gegpCkwrNWbK7A05Jnu/SedYs=";
    };

    build-system = [ python.hatchling ];
    dependencies = with python; [
      brotli
      click
      click-default-group
      httpx
      openapi-pydantic
      pydantic
      pydantic-settings
      pyperclip
      python-dotenv
      pyyaml
      textual
      textual-autocomplete
      watchfiles
      xdg-base-dirs
    ];

    checkPhase = ''
      runHook preCheck
      ${python.python}/bin/python -m compileall -q src/posting
      runHook postCheck
    '';
    pythonImportsCheck = [ "posting" ];
    postFixup = ''
      HOME="$TMPDIR" $out/bin/posting --help >/dev/null
    '';

    meta = {
      description = "Modern API client that lives in your terminal";
      homepage = "https://github.com/wahh-22/posting";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "posting";
    };
  };
in
{
  home.packages = [ posting ];
}

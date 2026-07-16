{
  fetchFromGitHub,
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "mempalace";
  version = "3.5.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mempalace";
    repo = "mempalace";
    tag = "v3.5.0";
    hash = "sha256-C4KPtHNTHTwQXgWUsiRWC0J16tj2wGI7XI/gKGjNgRE=";
  };

  build-system = [
    python3Packages.hatchling
  ];

  dependencies = with python3Packages; [
    chromadb
    pyyaml
    huggingface-hub
    tokenizers
    numpy
    python-dateutil
  ];

  pythonImportsCheck = [ "mempalace" ];

  meta = {
    description = "Give your AI a memory — mine projects and conversations into a searchable palace";
    homepage = "https://github.com/mempalace/mempalace";
    license = lib.licenses.mit;
    mainProgram = "mempalace";
  };
}

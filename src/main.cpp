#include "analysisoptions.hpp"
#include "langserver.hpp"
#include "libwrap/wrap.hpp"
#include "mesonmetadata.hpp"
#include "mesontree.hpp"
#include "typenamespace.hpp"

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <node.hpp>
#include <sourcefile.hpp>
#include <string>
#include <tree_sitter/api.h>
#include <vector>

extern "C" TSLanguage *tree_sitter_meson(); // NOLINT

void printHelp() {
  std::cerr << "Usage: Swift-MesonLSP [<options>] [<paths> ...]" << std::endl
            << std::endl;
  std::cerr << "ARGUMENTS:" << std::endl;
  std::cerr << "  <paths>\tPath to parse" << std::endl << std::endl;
  std::cerr << "OPTIONS:" << std::endl;
  std::cerr
      << "--path <path>\t\t\tPath to parse 100x times (default: ./meson.build)"
      << std::endl;
  std::cerr << "--lsp        \t\t\tStart language server using stdio"
            << std::endl;
  std::cerr << "--wrap <wrapFile>\t\tExtract and parse this wrap file"
            << std::endl;
  std::cerr << "--wrap-output <dir>\t\tSet the directory into that the given "
               "wraps should be extracted."
            << std::endl;
  std::cerr << "--wrap-package-files <dir>\tSet the location of the package "
               "files containing auxiliary files"
            << std::endl;
  std::cerr
      << "--full \t\t\tFully setup and check a project (Includes subprojects)"
      << std::endl;
  std::cerr << "--version    \t\t\tPrint version" << std::endl;
  std::cerr << "--help       \t\t\tPrint this help" << std::endl;
}

void printVersion() {
  std::cout << "Swift-MesonLSP version: " << VERSION << std::endl;
  std::cout << "Using C compiler:       " << CC_VERSION << std::endl;
  std::cout << "Using C++ compiler:     " << CXX_VERSION << std::endl;
  std::cout << "Linker:                 " << LINKER_ID << std::endl;
}

void startLanguageServer() {
  auto handler = std::make_shared<LanguageServer>();
  auto server = std::make_shared<jsonrpc::JsonRpcServer>();
  handler->server = server;
  server->loop(handler);
  server->wait();
}

int parseWraps(const std::vector<std::string> &wraps, const std::string &output,
               const std::string &packageFiles) {
  if (output.empty()) {
    std::cerr << "No output directory given. Use --wrap-output" << std::endl;
    return EXIT_FAILURE;
  }
  if (packageFiles.empty()) {
    std::cerr << "No package files directory given. Use --wrap-package-files"
              << std::endl;
    return EXIT_FAILURE;
  }
  auto outputFs = std::filesystem::path(output);
  std::filesystem::create_directories(outputFs);
  auto packageFilesFs = std::filesystem::path(packageFiles);
  if (!std::filesystem::exists(packageFilesFs)) {
    std::cerr << output << " does not exist" << std::endl;
    return EXIT_FAILURE;
  }
  auto error = false;
  for (const auto &wrap : wraps) {
    auto wrapFs = std::filesystem::path(wrap);
    if (!std::filesystem::exists(wrapFs)) {
      std::cerr << wrapFs << " does not exist" << std::endl;
      error = true;
      continue;
    }
    auto ptr = parseWrap(wrapFs);
    if (!ptr || !ptr->serializedWrap) {
      continue;
    }
    ptr->serializedWrap->setupDirectory(outputFs, packageFilesFs);
  }
  return error ? EXIT_FAILURE : EXIT_SUCCESS;
}

void printDiagnostics(const MesonTree &tree) {
  auto projects = tree.flatten();
  for (const auto &proj : projects) {
    const auto &metadata = proj->metadata;
    if (metadata.diagnostics.empty()) {
      continue;
    }
    std::cerr << "Diagnostics for project " << proj->identifier << " ("
              << std::filesystem::absolute(proj->root).generic_string() << ")"
              << std::endl;
    auto keyview = std::views::keys(metadata.diagnostics);
    std::vector<std::filesystem::path> keys{keyview.begin(), keyview.end()};
    std::sort(keys.begin(), keys.end());
    for (const auto &file : keys) {
      auto relative =
          std::filesystem::relative(file, proj->root).generic_string();
      auto diags = proj->metadata.diagnostics.at(file);
      for (const auto &diag : diags) {
        const auto *icon = diag.severity == Severity::Error ? "🔴" : "⚠️";
        std::cerr << relative << "[" << diag.startLine + 1 << ":"
                  << diag.startColumn << "] " << icon << "  " << diag.message
                  << std::endl;
      }
    }
  }
}

int main(int argc, char **argv) {
  std::locale::global(std::locale(""));
  std::string path = "./meson.build";
  std::vector<std::string> paths;
  std::vector<std::string> wraps;
  std::string wrapOutput;
  std::string wrapPackageFiles;
  bool lsp = false;
  bool help = false;
  bool version = false;
  bool error = false;
  bool full = false;
  for (int i = 1; i < argc; i++) {
    if (strcmp("--lsp", argv[i]) == 0) {
      lsp = true;
      continue;
    }
    if (strcmp("--full", argv[i]) == 0) {
      full = true;
      continue;
    }
    if (strcmp("--stdio", argv[i]) == 0) {
      continue;
    }
    if (strcmp("--help", argv[i]) == 0) {
      help = true;
      continue;
    }
    if (strcmp("--version", argv[i]) == 0) {
      version = true;
      continue;
    }
    if (strcmp("--path", argv[i]) == 0) {
      if (i + 1 == argc) {
        std::cerr << "Error: Missing value for --path <path>" << std::endl;
        error = true;
        break;
      }
      path = std::string(argv[i + 1]);
      i++;
      continue;
    }
    if (strcmp("--wrap", argv[i]) == 0) {
      if (i + 1 == argc) {
        std::cerr << "Error: Missing value for --wrap <wrap-file>" << std::endl;
        error = true;
        break;
      }
      wraps.emplace_back(argv[i + 1]);
      i++;
      continue;
    }
    if (strcmp("--wrap-output", argv[i]) == 0) {
      if (i + 1 == argc) {
        std::cerr << "Error: Missing value for --wrap-output <directory>"
                  << std::endl;
        error = true;
        break;
      }
      wrapOutput = std::string(argv[i + 1]);
      i++;
      continue;
    }
    if (strcmp("--wrap-package-files", argv[i]) == 0) {
      if (i + 1 == argc) {
        std::cerr << "Error: Missing value for --wrap-package-files <directory>"
                  << std::endl;
        error = true;
        break;
      }
      wrapPackageFiles = std::string(argv[i + 1]);
      i++;
      continue;
    }
    if (strncmp(argv[i], "--", 2) == 0) {
      std::cerr << "Unknown option: " << argv[i] << std::endl;
      error = true;
      continue;
    }
    paths.emplace_back(argv[i]);
  }
  if (error || help) {
    printHelp();
    return error ? EXIT_FAILURE : EXIT_SUCCESS;
  }
  if (version) {
    printVersion();
    return EXIT_SUCCESS;
  }
  if (lsp) {
    startLanguageServer();
    return EXIT_SUCCESS;
  }
  if (!wraps.empty()) {
    return parseWraps(wraps, wrapOutput, wrapPackageFiles);
  }
  if (paths.empty()) {
    auto parent = std::filesystem::absolute(path).parent_path();
    TypeNamespace const ns;
    MesonTree tree(parent, ns);
    AnalysisOptions const opts(false, false, false, false, false, false, false);
    if (full) {
      tree.fullParse(opts, true);
    } else {
      tree.partialParse(opts);
    }
    printDiagnostics(tree);
    return 0;
  }
  TypeNamespace const ns;
  AnalysisOptions const opts(false, false, false, false, false, false, false);
  for (const auto &toParse : paths) {
    auto parent = std::filesystem::absolute(toParse).parent_path();
    for (int i = 0; i < 100; i++) {
      MesonTree tree(parent, ns);
      tree.partialParse(opts);
    }
  }
  return 0;
}

#include "typenamespace.hpp"

#include "type.hpp"

#include <memory>
#include <string>
#include <vector>

TypeNamespace::TypeNamespace() {
  std::vector<std::shared_ptr<Type>> const dictTypes;
  std::vector<std::shared_ptr<Type>> const listTypes;
  std::vector<std::string> const names;
  this->types = {
      {"any", std::make_shared<Any>()},
      {"bool", this->boolType},
      {"build_machine", std::make_shared<BuildMachine>()},
      {"dict", std::make_shared<Dict>(dictTypes)},
      {"host_machine", std::make_shared<HostMachine>()},
      {"int", this->intType},
      {"list", std::make_shared<List>(listTypes)},
      {"meson", std::make_shared<Meson>()},
      {"str", this->strType},
      {"target_machine", std::make_shared<TargetMachine>()},
      {"alias_tgt", std::make_shared<AliasTgt>()},
      {"both_libs", std::make_shared<BothLibs>()},
      {"build_tgt", std::make_shared<BuildTgt>()},
      {"cfg_data", std::make_shared<CfgData>()},
      {"compiler", std::make_shared<Compiler>()},
      {"custom_idx", std::make_shared<CustomIdx>()},
      {"custom_tgt", std::make_shared<CustomTgt>()},
      {"dep", std::make_shared<Dep>()},
      {"disabler", std::make_shared<Disabler>()},
      {"env", std::make_shared<Env>()},
      {"exe", std::make_shared<Exe>()},
      {"external_program", std::make_shared<ExternalProgram>()},
      {"extracted_obj", std::make_shared<ExtractedObj>()},
      {"feature", std::make_shared<Feature>()},
      {"file", std::make_shared<File>()},
      {"generated_list", std::make_shared<GeneratedList>()},
      {"generator", std::make_shared<Generator>()},
      {"inc", std::make_shared<Inc>()},
      {"jar", std::make_shared<Jar>()},
      {"lib", std::make_shared<Lib>()},
      {"module", std::make_shared<Module>()},
      {"range", std::make_shared<Range>()},
      {"runresult", std::make_shared<RunResult>()},
      {"run_tgt", std::make_shared<RunTgt>()},
      {"structured_src", std::make_shared<StructuredSrc>()},
      {"subproject", std::make_shared<Subproject>(names)},
      {"tgt", std::make_shared<Tgt>()},
      {"cmake_module", std::make_shared<CMakeModule>()},
      {"cmake_subproject", std::make_shared<CMakeSubproject>()},
      {"cmake_subprojectoptions", std::make_shared<CMakeSubprojectOptions>()},
      {"cmake_tgt", std::make_shared<CMakeTarget>()},
      {"fs_module", std::make_shared<FSModule>()},
      {"i18n_module", std::make_shared<I18nModule>()},
      {"gnome_module", std::make_shared<GNOMEModule>()},
      {"rust_module", std::make_shared<RustModule>()},
      {"python_module", std::make_shared<PythonModule>()},
      {"python_installation", std::make_shared<PythonInstallation>()},
      {"python3_module", std::make_shared<Python3Module>()},
      {"pkgconfig_module", std::make_shared<PkgconfigModule>()},
      {"keyval_module", std::make_shared<KeyvalModule>()},
      {"dlang_module", std::make_shared<DlangModule>()},
      {"external_project_module", std::make_shared<ExternalProjectModule>()},
      {"external_project", std::make_shared<ExternalProject>()},
      {"hotdoc_module", std::make_shared<HotdocModule>()},
      {"hotdoc_target", std::make_shared<HotdocTarget>()},
      {"java_module", std::make_shared<JavaModule>()},
      {"windows_module", std::make_shared<WindowsModule>()},
      {"cuda_module", std::make_shared<CudaModule>()},
      {"icestorm_module", std::make_shared<IcestormModule>()},
      {"qt4_module", std::make_shared<Qt4Module>()},
      {"qt5_module", std::make_shared<Qt5Module>()},
      {"qt6_module", std::make_shared<Qt6Module>()},
      {"wayland_module", std::make_shared<WaylandModule>()},
      {"simd_module", std::make_shared<SIMDModule>()},
      {"sourceset_module", std::make_shared<SourceSetModule>()},
      {"sourceset", std::make_shared<SourceSet>()},
      {"source_configuration", std::make_shared<SourceConfiguration>()}};
  this->initFunctions();
  this->initMethods();
  this->initObjectDocs();
}

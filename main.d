module main;

import tango.io.Stdout;
import tango.text.Util;
import Path = tango.io.Path;
import tango.io.FilePath;

import ast.module_node;

import lex.lexer;
import syntax.parser;
import logger;

static const char[] USAGE = "Usage: seshat <main-d-file>";

extern(C) int system(char* path);

struct FileInfo {
  char[] path;
  char[] implementationPath;
  char[] name;
}

FileInfo[] _done;

bool hasDone(char[] path) {
  foreach(p; _done) {
    if (p.path == path || p.implementationPath == path) {
      return true;
    }
  }
  return false;
}

int link(char[] path) {
  return system(("ldc .seshat-build-cache/*.o -of" ~ path ~ "\0").ptr);
}

int compileFile(char[] path, char[] moduleName, char[][] importPaths, char[] flags) {
  char[] outputPath = ".seshat-build-cache/" ~ moduleName.replace('.', '-') ~ ".o";

  if (Path.exists(outputPath)) {
    auto outputFile = new FilePath(outputPath);
    auto sourceFile = new FilePath(path);

    if (outputFile.modified > sourceFile.modified) {
      return 0;
    }
  }

  char[] compileString = "ldc -c " ~ path ~ " -of" ~ outputPath ~ " " ~ flags;
  foreach(importPath; importPaths) {
    compileString ~= "-I" ~ importPath ~ " ";
  }

  compileString ~= "\0";
  return system(compileString.ptr);
}

ModuleNode parse(char[] path) {
  Stdout("Parsing ")(path)("...").newline;

  auto lex    = new Lexer(path);
  auto logger = new Logger();
  auto parser = new Parser(lex);
  auto ast    = parser.parse(logger);

  return ast;
}

void findImplementation(ref FileInfo fileInfo, char[][] importPaths) {
  Stdout("Finding implementation for ")(fileInfo.name)("...").newline;
  if (fileInfo.path[$-2..$] == ".d") {
    fileInfo.implementationPath = fileInfo.path;
    return;
  }

  char[] imp = fileInfo.name;
  imp = imp.dup.replace('.', '/');
  imp ~= ".d";

  // Determine location of .d or .di

  bool fileExists = false;
  char[] testPath = "";
  foreach(path; importPaths) {
    testPath = path ~ "/" ~ imp;
    if (Path.exists(testPath)) {
      fileExists = true;
      break;
    }
  }

  if (!fileExists) {
    Stdout("Cannot find file for import ")(imp).newline;
  }
  else {
    // We need to parse the imports for this file as well
    Stdout("Found implementation ")(testPath).newline;
    fileInfo.implementationPath = testPath;
    parseFile(testPath, importPaths, true);
  }
}

void parseFile(char[] filePath, char[][] importPaths, bool forceParsing = false) {
  if (!forceParsing && hasDone(filePath)) {
    return;
  }

  // Pull dependencies from given file
  auto ast = parse(filePath);

  FileInfo f;
  f.path = filePath;
  f.name = ast.name;
  _done ~= f;

  // Query for implementations

  // Compile
  foreach(importNode; ast.imports) {
    Stdout("Found import ")(importNode.moduleName)(".").newline;
    char[] imp = importNode.moduleName;
    // Convert to path
    imp = imp.replace('.', '/');
    imp ~= ".d";

    // Determine location of .d or .di

    bool fileExists = false;
    char[] testPath = "";
    foreach(path; importPaths) {
      testPath = path ~ "/" ~ imp;
      if (Path.exists(testPath)) {
        fileExists = true;
      }
      else {
        testPath ~= "i";
        if (Path.exists(testPath)) {
          fileExists = true;
        }
      }

      if (fileExists) {
        break;
      }
    }

    if (!fileExists) {
      Stdout("Cannot find file for import ")(imp).newline;
    }
    else {
      parseFile(testPath, importPaths);
    }
  }
}

int main(char[][] args) {
  if (args.length < 2) {
    Stdout(USAGE).newline;
    return -1;
  }

  char[][] importPaths = [];
  char[] outputPath = "./output";
  char[] flags = "";

  // Set default output path to name of main source file minus extension
  foreach(size_t idx, chr; args[1]) {
    if (chr == '.') {
      outputPath = "./" ~ args[1][0..idx];
    }
  }

  // Parse arguments for certain flags
  foreach(arg; args[2..$]) {
    if (arg.length > 2 && arg[0..2] == "-o") {
      outputPath = arg[2..$];
    }
    else if (arg.length == 2 && arg == "-d") {
      flags ~= "-g ";
    }
    else {
      importPaths ~= arg;
    }
  }

  importPaths ~= ".";

  parseFile(args[1], importPaths);

  double p = 0.0;

  for(size_t idx = 0; idx < _done.length; idx++) {
    // Compile
    auto file = _done[idx];
    findImplementation(_done[idx], importPaths);
    file = _done[idx];
  }

  foreach(size_t idx, file; _done) {
    p = (cast(double)idx+1) / (cast(double)_done.length+1);
    Stdout("[")(cast(int)(p*100))("%] - ")(file.name).newline;
    if (file.implementationPath !is null && file.implementationPath != "") {
      if (compileFile(file.implementationPath, file.name, importPaths, flags) != 0) {
        Stdout("Errors reported. Cancelling build.").newline;
        return -1;
      }
    }
  }

  link(outputPath);

  return 0;
}

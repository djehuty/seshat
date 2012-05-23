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
    if (p.path == path) {
      return true;
    }
  }
  return false;
}

int link(char[] path) {
  return system("ldc .seshat-build-cache/*.o -ofblah");
}

int compileFile(char[] path, char[] moduleName, char[][] importPaths) {
  char[] outputPath = ".seshat-build-cache/" ~ moduleName.replace('.', '-') ~ ".o";

  if (Path.exists(outputPath)) {
    auto outputFile = new FilePath(outputPath);
    auto sourceFile = new FilePath(path);

    if (outputFile.modified > sourceFile.modified) {
      return 0;
    }
  }

  char[] compileString = "ldc -c " ~ path ~ " -of" ~ outputPath ~ " ";
  foreach(importPath; importPaths) {
    compileString ~= "-I" ~ importPath ~ " ";
  }

  compileString ~= "\0";
  Stdout(compileString).newline;
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
  if (fileInfo.path[$-2..$] == ".d") {
    fileInfo.implementationPath = fileInfo.path;
    return;
  }

  char[] imp = fileInfo.name;
  imp = imp.replace('.', '/');
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
    fileInfo.implementationPath = testPath;
  }
}

void parseFile(char[] filePath, char[][] importPaths) {
  if (hasDone(filePath)) {
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

  char[][] importPaths = args[2..$];

  parseFile(args[1], importPaths);

  double p = 0.0;

  foreach(size_t idx, file; _done) {
    // Compile
    p = (cast(double)idx+1) / cast(double)_done.length;
    Stdout("[")(cast(int)(p*100))("%] - ")(file.name).newline;
    findImplementation(_done[idx], importPaths);
    file = _done[idx];
    compileFile(file.implementationPath, file.name, importPaths);
  }

  link("");

  return 0;
}

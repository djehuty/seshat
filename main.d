module main;

import tango.io.Stdout;
import tango.text.Util;
import Path = tango.io.Path;

import ast.module_node;

import lex.lexer;
import syntax.parser;
import logger;

static const char[] USAGE = "Usage: seshat <main-d-file>";

extern(C) int system(char* path);

struct FileInfo {
  char[] path;
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
  return system("ldc output/*.o -ofblah");
}

int compileFile(char[] path, char[] moduleName, char[][] importPaths) {
  char[] compileString = "ldc -c " ~ path ~ " -ofoutput/" ~ moduleName.replace('.', '-') ~ ".o ";

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
    compileFile(file.path, file.name, importPaths);
  }

  link("");

  return 0;
}

import tango.io.Stdout;
import tango.text.Util;
import Path = tango.io.Path;

import lex.lexer;
import syntax.parser;
import logger;

static const char[] USAGE = "Usage: seshat <main-d-file>";

char[][] done;

bool hasDone(char[] path) {
  foreach(p; done) {
    if (p == path) {
      return true;
    }
  }
  return false;
}

char[][] getDependencies(char[] path) {
  Stdout("Parsing ")(path)("...").newline;

  auto lex    = new Lexer(path);
  auto logger = new Logger();
  auto parser = new Parser(lex);
  auto ast    = parser.parse(logger);

  char[][] ret = [];
  foreach(decl; ast.imports) {
    ret ~= decl.moduleName;
  }

  return ret;
}

void parseFile(char[] filePath, char[][] importPaths) {
  if (hasDone(filePath)) {
    return;
  }

  done ~= filePath;

  // Pull dependencies from given file
  char[][] imports = getDependencies(filePath);

  // Query for implementations

  // Compile
  foreach(imp; imports) {
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

  return 0;
}

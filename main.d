import tango.io.Stdout;
import tango.text.Util;
import Path = tango.io.Path;

import lex.lexer;
import syntax.parser;
import logger;

static const char[] USAGE = "Usage: seshat <main-d-file>";

char[][] getDependencies(char[] path) {
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

int main(char[][] args) {
  if (args.length < 2) {
    Stdout(USAGE).newline;
    return -1;
  }

  char[][] importPaths = args[2..$];

  // Pull dependencies from given file
  char[][] imports = getDependencies(args[1]);

  // Query for implementations

  // Compile
  foreach(imp; imports) {
    // Convert to path
    imp = imp.replace('.', '/');
    imp ~= ".d";

    // Determine location of .d or .di

    bool fileExists = false;
    foreach(path; importPaths) {
      auto testPath = path ~ "/" ~ imp;
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
        Stdout(testPath).newline;
        break;
      }
    }

    if (!fileExists) {
      Stdout("Cannot find file for import ")(imp).newline;
    }
  }

  return 0;
}

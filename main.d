import tango.io.Stdout;

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

  // Pull dependencies from given file
  char[][] imports = getDependencies(args[1]);

  // Query for implementations

  // Compile
  foreach(imp; imports) {
    Stdout(imp).newline;
  }

  return 0;
}

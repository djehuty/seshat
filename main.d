import tango.io.Stdout;

static const char[] USAGE = "Usage: seshat <main-d-file>";

int main(char[][] args) {
  if (args.length < 2) {
    Stdout(USAGE).newline;
  }

  // Pull dependencies from given file

  // Query for implementations

  // Compile
  return 0;
}

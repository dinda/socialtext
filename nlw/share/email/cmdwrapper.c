#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

// usage:
// 1. modify UID below.
// 2. compile this.
// 3. create SCRIPT.sh
// 4. rename this program to SCRIPT name.
// 5. chown root SCRIPT
// 6. chmod u+s SCRIPT

#define UID (33)

int main(int argc, char *argv[]) {
  setuid(UID); // These function need root privs.
  seteuid(UID);

  char *name = (char*)malloc(strlen(argv[0]) + 4);
  if (name == NULL)
  {
	  return 1;
  }

  strcpy(name, argv[0]);
  strcat(name, ".sh");

  execv(name, argv);

  free(name);

  return 0;
}

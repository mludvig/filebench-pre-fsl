#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int
main(int argc, char *argv[], char *envp[])
{
	char *shell;
	char cmd[2048];

	*cmd = '\0';
	shell=getenv("SHELL");
	argv++;
	argc--;
	while(argc-- != 0) {
		(void) strcat(cmd,*argv);
		(void) strcat(cmd," ");
		argv++;
	}

	execlp(shell, shell, "-c", cmd, (char *) 0);

	/* NOT REACHED */
	return (-1);
}

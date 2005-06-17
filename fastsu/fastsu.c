#include        <unistd.h>
#include        <stdio.h>
#include        <stdlib.h>

main(int argc, char *argv[], char *envp[])
{
	char *shell;
	char cmd[2048];

	*cmd = NULL;
	shell=getenv("SHELL");
        *(argv++);
	argc--;
	while(argc-- != 0)
	{       strcat(cmd,*argv);
	        strcat(cmd," ");
	        *(argv++);
	}

 execlp(shell, shell, "-c", cmd, (char *) 0);

}




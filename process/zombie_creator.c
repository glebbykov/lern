#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <signal.h>

void create_zombie() {
    pid_t pid = fork();

    if (pid == 0) {
        // Child exits immediately
        exit(0);
    } else {
        // Parent sleeps to keep the child in a zombie state
        sleep(30);
    }
}

int main() {
    pid_t pid, sid;

    // Fork off the parent process
    pid = fork();
    if (pid < 0) {
        exit(EXIT_FAILURE);
    }
    // If we got a good PID, then we can exit the parent process.
    if (pid > 0) {
        exit(EXIT_SUCCESS);
    }

    // Change the file mode mask
    umask(0);
            
    // Open any logs here        
            
    // Create a new SID for the child process
    sid = setsid();
    if (sid < 0) {
        // Log the failure
        exit(EXIT_FAILURE);
    }
        
    // Change the current working directory
    if ((chdir("/")) < 0) {
        // Log the failure
        exit(EXIT_FAILURE);
    }
        
    // Close out the standard file descriptors
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
        
    // Daemon-specific initialization goes here

    // The Big Loop
    while (1) {
       // Do some task here ...
       create_zombie();  // This will create a zombie every 5 minutes
       sleep(300); // sleep 5 minutes
    }
   exit(EXIT_SUCCESS);
}

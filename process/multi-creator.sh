#!/bin/bash

pid_file="./pids.txt"

# Function to add PID to a file
add_pid_to_file() {
    echo $1 >> $pid_file
}

# Function to send signals
send_signal() {
    echo "Enter the PID of the process:"
    read pid
    echo "Select the signal to send:"
    echo "1) SIGSTOP - stop the process"
    echo "2) SIGCONT - continue the process"
    echo "3) SIGKILL - immediately terminate the process"
    read option

    case $option in
        1) kill -SIGSTOP $pid;;
        2) kill -SIGCONT $pid;;
        3) kill -SIGKILL $pid;;
        *) echo "Invalid input"; exit 1;;
    esac

    echo "Signal sent to process with PID $pid"
}

# Function to create a zombie process through a daemon
create_zombie() {
    echo "Creating a zombie process through a daemon..."
    (
    (sleep 1 & exec sleep 9999) &
    exit 0
    ) &
    wait $!
    pid=$(pgrep -n sleep)
    echo "Zombie process created with PID $pid"
    add_pid_to_file $pid
}

# Function to create a background process
create_background() {
    echo "Starting a background process..."
    sleep 300 &
    pid=$!
    echo "Background process started with PID $pid"
    add_pid_to_file $pid
}

# Function to create a stopped process
create_stopped() {
    echo "Starting and stopping the process..."
    sleep 300 &
    pid=$!
    kill -SIGSTOP $pid
    echo "Process started and stopped with PID $pid"
    add_pid_to_file $pid
}

# Function to track processes
track_processes() {
    echo "Tracking processes created by this script..."
    if [ -f $pid_file ]; then
        while read pid; do
            if [ -z "$(ps -p $pid -o pid=)" ]; then
                echo "Process with PID $pid does not exist."
            else
                ps -p $pid -o pid,ppid,state,cmd
            fi
        done < $pid_file
    else
        echo "PID file not found."
    fi
}

# Function to execute a custom command
execute_command() {
    echo "Enter the command to execute:"
    read user_command
    echo "Executing command '$user_command'..."
    eval $user_command
    echo "Command executed."
}

# Main menu of the script
echo "Select an operation:"
echo "1) Send signal to a process"
echo "2) Create a zombie process"
echo "3) Create a background process"
echo "4) Create a stopped process"
echo "5) Track processes"
echo "6) Execute a custom command"
read choice

case $choice in
    1) send_signal;;
    2) create_zombie;;
    3) create_background;;
    4) create_stopped;;
    5) track_processes;;
    6) execute_command;;
    *) echo "Incorrect choice"; exit 1;;
esac

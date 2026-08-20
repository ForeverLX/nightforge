package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func niriMsg(args ...string) (string, error) {
	cmd := exec.Command("niri", append([]string{"msg"}, args...)...)
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: tweaks <command>")
		fmt.Println("Commands: window-details, fuzzel-toggle")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "window-details":
		output, err := niriMsg("-j", "focused-window")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		var window map[string]interface{}
		json.Unmarshal([]byte(output), &window)
		if id, ok := window["app_id"]; ok {
			fmt.Printf("App ID: %v\n", id)
		}
		if title, ok := window["title"]; ok {
			fmt.Printf("Title: %v\n", title)
		}
		fmt.Println(output)

	case "fuzzel-toggle":
		check := exec.Command("pgrep", "-x", "fuzzel")
		if err := check.Run(); err != nil {
			exec.Command("fuzzel").Start()
		} else {
			exec.Command("pkill", "-x", "fuzzel").Run()
		}
	}
}
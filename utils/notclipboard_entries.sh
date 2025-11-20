#!/usr/bin/env bash

# Combine all entry generators except clipboard
notclipboard_entries() {
  windows_entries
  cust_entries
  apps_entries
  history_entries
  web_entries
  sys_entries
}

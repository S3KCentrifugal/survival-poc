#!/usr/bin/env bash
SESSION_NAME="${1:-SurvivalGamePoc}"
claude --rc -c -n "$SESSION_NAME" --permission-mode auto 2>/dev/null \
  || claude --rc -n "$SESSION_NAME" --permission-mode auto

# Bring-up log

One entry per test run, newest first. Raw output lives in `logs/<run-id>/`.

Template:

```
## <run-id> – <YYYY-MM-DD> – <phase> – <PASS|FAIL|HANG>
- Change: <the one variable changed in this step>
- Kernel: <tag + patch count>, config: <fragments>
- Result: <login / panic / hang at ...>
- Notes: <findings, next step>
```

---

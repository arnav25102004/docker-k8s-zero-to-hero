# Section 4: Configuration, storage and security

ConfigMaps and Secrets, persistent storage, RBAC and Pod security.

**Syllabus topics:** ConfigMaps and Secrets, persistent storage, RBAC, security policies.

## The five scenarios (4 minutes each)

| # | Scenario | What it teaches | The hook |
|---|---|---|---|
| **S4.1** | [Dark mode is on. The site is still white.](1-dark-mode-not-applied/README.md) | ConfigMap: env vs live | *Dark mode is ON in the config. The site is still blinding white.* |
| **S4.2** | [The container that never got created](2-adminer-missing-secret/README.md) | Secret: missing key | *The database tool won't even start. No logs. Nothing.* |
| **S4.3** | [The task board is waiting for a disk that will never arrive](3-kanboard-pvc-pending/README.md) ⏳ | PersistentVolumeClaim, StorageClass | *The Pod isn't crashing. It isn't even starting. It's waiting for a disk that doesn't exist.* |
| **S4.4** | [The bot has an ID card, but the door stays shut](4-leaderboard-bot-forbidden/README.md) | RBAC, ServiceAccounts | *The bot has a valid ID card. The API still says: not allowed.* |
| **S4.5** | [The rule that turned the lights off](5-notice-board-runasnonroot/README.md) | securityContext: runAsNonRoot | *Security turned on one rule. The notice board went dark.* |

## Exercises (self-paced, with hints)

| # | Exercise | What it teaches |
|---|---|---|
| **S4.x1** | [Locked down and locked out](exercises/1-notice-board-readonly-fs/README.md) | read-only root filesystem |
| **S4.x2** | [The maintenance van wants the master key](exercises/2-maintenance-van-wants-the-master-key/README.md) | Pod Security: baseline |
| **S4.x3** | [The checklist](exercises/3-the-checklist/README.md) | Pod Security: restricted checklist |
| **S4.x4** | [The locked-down kitchen](exercises/4-the-locked-down-kitchen/README.md) | Pod Security: boss |
| **S4.x5** | [The file that outlived the Pod](exercises/5-the-file-that-outlived-the-pod/README.md) | PersistentVolumeClaim, volumes, StorageClass, data outliving a Pod |

⏳ = start its `break.sh` one scenario early: it takes longer than a minute to set up or to fix.

← [All sections](../README.md)

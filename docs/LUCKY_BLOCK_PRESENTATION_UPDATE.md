# Lucky Block presentation follow-up - October 30, 2026

The existing Lucky working diff now retains the authored reward as its collectible and shows successful claim feedback on the claimer's HUD. Reward weights/durations, cash/combat/sprint effects, overfill transactions, spawn distribution, and session-only persistence boundaries are unchanged.

## Review location and unrelated work

The shared checkout was switched externally from lucky-block-rewards to feature/framewisp-hotbar during this task. Concurrent UI/export/validation-file edits were preserved. The complete Lucky-only working diff is also applied in an isolated worktree on **lucky-block-rewards**:

`C:/Users/Collin Van Meter/AppData/Local/Temp/BlenderGame-lucky-block-validation-20261030-1541a6c/lucky-block-rewards`

No commit, merge or publication was performed. The review patch excludes the concurrent hotbar/UI/export changes. The shared bootstrap retains the other task's additions; the isolated Lucky bootstrap includes only the Lucky HUD addition to its incoming version. Review artifact: `../LuckyBlocks-with-presentation.patch` relative to the worktree root.

## Persistent authored prize

- `shared/LuckyBlockRewardVisual` owns the existing clone sanitization/normalization plus a common settled pose. The client LuckyBlockVisual module wraps it. Both colored reveal and public art use the same ModelSize, HeightOffset, TiltDegrees and RevealYawDegrees.
- The server resolves each presentation Visual name in ReplicatedStorage.LuckyBlockVisuals. It never substitutes the Lucky Block template for a prize. Reward parts are anchored and inert. Public prizes use their own LuckyRewardPickup tag, so only unopened LuckyBlockWorld models bob/rotate.
- A non-geometric identity container replicates as Pending during roulette. The unchanged task.delay reveal+hold+fade deadline creates its public art and activates server claims; it starts the unchanged 60-second lifetime then. Pending identity cannot be collected.
- `LuckyBlockPickupHandoff` initially hides public parts/effects while descendants replicate. At the expected part count it releases the local colored prize before showing public art in the same render update. Roulette fade affects only temporary lettering/light; its final prize stays at settled scale through sequence end, roller death/leave, or delayed replication.
- Claim/expiry state also releases a retained reveal when terminal state arrives before art. After success the server immediately removes reward art and the label, retaining only terminal identity until the original expiry. This prevents late replication from resurrecting a local reveal. Failed claims restore the same pickup identity, authored appearance/pose and remaining original lifetime. No client acknowledgment or new claim remote exists.
- The finite 60-stud name billboard uses an Attachment on Terrain, giving missing-art fallback a world position without a generated part/mesh. `WorldUtil.NearPosition` reuses the existing living/root/gameplay-lock checks at the original block position; ordinary Near now delegates to that same check after resolving its part.

## Claimer HUD and replication

Only after a successful award, LuckyBlockService sets server-owned player attributes:

- Timed: `LuckyBuff<RewardId>ExpiresAt` (CashBoost, StarPower, MegaBat, Invincibility).
- Instant: `LuckyInstant<RewardId>Until` (PantryPack, TopShelf, MysteryBox), a 2.5-second confirmation deadline.

Rolling and failed awards write no message. Values go on the actual claimer, independently of the roller. The private server buff table still authorizes effects; client attributes do not authorize any action. RemovePlayer clears the attributes; character death keeps the existing buff-survival policy.

LuckyBlockMessages reads the presentation names and computes `math.ceil(math.max(0, expiresAt - workspace:GetServerTimeNow()))`. Expired entries disappear. HUD rows are keyed by reward ID, so refresh updates one row and independent buffs stack. Instant confirmations say COLLECTED with no countdown. LuckyBlockHudController reads only LocalPlayer attributes, refreshes at 0.1 seconds and recreates the display from current state if PlayerGui/ScreenGui is replaced. It does not start a receipt-based duration.

The HUD uses DialogueTextStyle: FredokaOne, white lettering and its opaque 2.5px dark outline. Entrance animation fades a CanvasGroup, including the outline, using the existing TutorialTooltip approach. Rows occupy the central 36% of CoreUISafeInsets space, below the tutorial/announcement banner (6.5% screen height plus its 104px extent and 12px gap), and above the hotbar/mobile control region (bottom at 72% landscape / 55% portrait). Row height responds to viewport height and active entry count. ResetOnSpawn is false. Automated layout cases cover desktop, landscape phone and narrow portrait viewports; no Studio testing tasks were added.

## Missing authored visual assets

None of these names is present as inspectable reward art in the repository's authored folders/XML exports. Their live place presence remains unverified. Runtime missing/malformed art warns by its exact mapped name and uses the readable world-label fallback; no geometry is invented.

| Reward | Expected LuckyBlockVisuals asset |
|---|---|
| CashBoost | 2xCash |
| StarPower | Star |
| MegaBat | MegaBat |
| Invincibility | Invincibility |
| PantryPack | PantryPack |
| TopShelf | TopShelf |
| MysteryBox | MysteryBox |

## Validation

Final validation ran in the isolated Lucky worktree. Tools: Luau 0.745, StyLua 2.6.0, Luau LSP 1.70.1 with Roblox definitions, Rojo 7.7.0. Downloaded tools/raw logs remain in the parent validation directory outside the diff.

Commands below show the executed arguments using PowerShell variables for the tool directory. The invocations were orchestrated with Python subprocess.

```powershell
$validationRoot = 'C:/Users/Collin Van Meter/AppData/Local/Temp/BlenderGame-lucky-block-validation-20261030-1541a6c'
Set-Location -LiteralPath "$validationRoot/lucky-block-rewards"
python tests/run_state_tests.py --luau "$validationRoot/luau/luau.exe" --suite lucky-block --suite lucky-inventory --suite lucky-combat --suite lucky-sprint --suite lucky-hud --suite lucky-handoff --suite lucky-block-roulette --suite lucky-block-view --suite lucky-block-controller --suite customer-payout --suite customer-payout-serve --suite icegun-combat --suite icegun-simulated-combat --suite combat --suite combat-launch --suite bat-knockback --suite carry-selection
python tests/run_state_tests.py --luau "$validationRoot/luau/luau.exe"
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' sourcemap --output "$validationRoot/presentation-final-sourcemap.json"
& 'C:/Users/Collin Van Meter/.aftman/tool-storage/rojo-rbx/rojo/7.7.0/rojo.exe' build -o "$validationRoot/presentation-final.rbxlx"
git diff --check
```

- Affected suites: **17/17 pass**, exit 0.
- Full suite: **98/130 pass**, exit 1. Incoming working-diff baseline: **96/128 pass**, with exactly the same 32 failures; the two new presentation suites pass. The existing initial-pass report names all 32 failures; no unrelated suite was fixed. The baseline was copied before editing and run via the same runner/Luau executable in `presentation-update-baseline`.
- StyLua formatting and `--check` pass for all changed Lucky Luau source/spec files, including the initial pass files and new modules. `git diff --check` passes. New-file patch application is also checked against untouched HEAD.
- The normal Rojo project build and sourcemap pass in the isolated worktree. An earlier shared-checkout attempt failed while the other task temporarily removed Framewisp_CCWMF.rbxmx; its unrelated asset work was left intact. No production project mapping was changed to bypass that failure.
- Roblox-aware typecheck exits 1 with **40 pre-existing diagnostics**, matching the incoming baseline after normalizing paths/source locations: CustomerRequests 22 missing DisplayText fields, CombatService 9 optional-value errors, JackedNoobService 8 Instance/refinement errors and CustomerService 1 Grade union error. There are no new diagnostics in this update. Baseline typechecking used a temporary source-equivalent map without the then-missing StarterGui export; final Lucky typechecking uses the actual project map.

The typecheck/source-format argument list for the complete Lucky diff is:

```powershell
$sourceFiles = @(
    "src/client/Controllers/LuckyBlockHudController.luau",
    "src/client/Controllers/LuckyBlockPresentationController.luau",
    "src/client/Controllers/LuckyBlockRouletteController.luau",
    "src/client/UI/LuckyBlockHud.luau",
    "src/client/UI/LuckyBlockMessages.luau",
    "src/client/UI/LuckyBlockPickupHandoff.luau",
    "src/client/UI/LuckyBlockView.luau",
    "src/client/UI/LuckyBlockVisual.luau",
    "src/client/init.client.luau",
    "src/server/Services/BatKnockback.luau",
    "src/server/Services/CombatService.luau",
    "src/server/Services/CustomerService.luau",
    "src/server/Services/InventoryService.luau",
    "src/server/Services/LuckyBlockService.luau",
    "src/server/Services/SprintService.luau",
    "src/server/Services/WorldUtil.luau",
    "src/server/init.server.luau",
    "src/shared/Constants/LuckyBlockConfig.luau",
    "src/shared/Constants/LuckyBlockPresentation.luau",
    "src/shared/LuckyBlockRewardVisual.luau"
)
& "$validationRoot/lsp/luau-lsp.exe" analyze --platform roblox --sourcemap "$validationRoot/presentation-final-sourcemap.json" --definitions "$validationRoot/roblox.d.luau" $sourceFiles
```

StyLua ran with the same source list plus all changed Lucky `.luau` specs/fixtures enumerated by the initial report and this follow-up manifest, using `stylua.exe <files>` then `stylua.exe --check <files>`.

Coverage includes authored model mapping, shared pose/scale, anchoring and separate animation tags, missing-art labels, claim/expiry removal and recovery, partial/terminal replication handoff, unchanged server claim deadline/lifetime, claimer-only attributes, delayed server-expiry countdowns, refresh without duplicates, all four simultaneous buffs, instant confirmations, shared HUD styling, safe layout, and UI recreation. Engine rendering/streaming/network behavior is simulated at the repository's mocked Roblox boundary; no live visual or Studio validation is claimed.

Raw outputs: `presentation-final-focused.txt`, `presentation-final-full.txt`, `presentation-final-typecheck.txt`, `presentation-incoming-all-typecheck.txt`, `presentation-incoming-suite.txt`, `presentation-build.txt`, and `presentation-format-check.txt` in the parent validation directory.

## Files changed by this follow-up

- `docs/LUCKY_BLOCKS.md`
- `docs/LUCKY_BLOCK_PRESENTATION_UPDATE.md`
- `docs/LUCKY_BLOCK_ROULETTE.md`
- `docs/LUCKY_BLOCK_VALIDATION.md`
- `src/client/Controllers/LuckyBlockHudController.luau`
- `src/client/Controllers/LuckyBlockPresentationController.luau`
- `src/client/Controllers/LuckyBlockRouletteController.luau`
- `src/client/UI/LuckyBlockHud.luau`
- `src/client/UI/LuckyBlockMessages.luau`
- `src/client/UI/LuckyBlockPickupHandoff.luau`
- `src/client/UI/LuckyBlockView.luau`
- `src/client/UI/LuckyBlockVisual.luau`
- `src/client/init.client.luau`
- `src/server/Services/LuckyBlockService.luau`
- `src/server/Services/WorldUtil.luau`
- `src/shared/Constants/LuckyBlockPresentation.luau`
- `src/shared/LuckyBlockRewardVisual.luau`
- `tests/README.md`
- `tests/fixtures/lucky_visual_geometry.luau`
- `tests/fixtures/roblox.luau`
- `tests/lucky_block.spec.luau`
- `tests/lucky_block_controller.spec.luau`
- `tests/lucky_block_view.spec.luau`
- `tests/lucky_handoff.spec.luau`
- `tests/lucky_hud.spec.luau`
- `tests/run_state_tests.py`

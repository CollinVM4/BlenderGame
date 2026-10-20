# Index preview coverage

The allowlist now covers all 53 DiscoveryCatalog ingredients. No 2D asset IDs were added.

`ScrapbookPreviewAssets.Init` clones sanitized existing prefabs from `ServerStorage.Ingredients` into `ReplicatedStorage.Shared.ScrapbookPreviewAssets` at startup. Supply models/parts named by canonical ID in the source folder; direct edits to the generated destination are replaced on startup.

The following 37 newly allowlisted IDs need their Studio preview availability checked (the live place assets are not in this checkout). Clone any absent prefabs; these are pending asset verification, not confirmed missing models:

`Blueberry`, `Cabbage`, `Cactus`, `Carrot`, `Cherries`, `Chili_Pepper`, `Chili_Sauce`, `Cinnamon`, `Cotton_Candy`, `Fish`, `French_Fries`, `Golden_Tomato`, `Green_Apple`, `Gummy_Bear`, `Hamburger`, `Ice`, `Kiwi`, `Lemon`, `Mango`, `Melon`, `Milk`, `Mystery`, `Noob`, `Onion`, `Orange`, `Peach`, `Player_Head`, `Pomegranate`, `Rainbow_Trout`, `Shell`, `Shit`, `Starfruit`, `Steak`, `Strawberry`, `Sushi`, `Tire`, `Worm`.

Run `docs/studio/ScrapbookPreviewAudit.luau` in the client Command Bar during Play to print the exact available/missing list and validate both silhouette and discovered rendering. Previously allowlisted IDs must also pass this audit. Review every Index card after placing assets. Studio asset availability and visual approval remain pending.

# Terrain textures

Source: [ambientCG](https://ambientcg.com), released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) — public domain,
no attribution required. Recorded here anyway, because "where did this file
come from" is a question that gets asked once the answer is hard to find.

| File | Original |
|---|---|
| `grass_color.jpg`, `grass_normal.jpg` | `Grass004` |
| `dirt_color.jpg`, `dirt_normal.jpg` | `Ground037` |
| `rock_color.jpg`, `rock_normal.jpg` | `Rock030` |

Downloaded as 1K JPG, **resized to 512×512** and re-encoded at quality 88.
That is 676 KB for all six rather than 13 MB, and at the distance this camera
sits from the ground the difference is not visible. Re-fetch the originals from
ambientCG if a closer camera ever needs them; they are not worth keeping in git
until something needs them.

Normal maps are the **GL** variants (`NormalGL`), not DirectX. Godot expects
+Y up; a DirectX map lights every bump from the wrong side, which reads as the
sun being in the wrong place rather than as a wrong texture.

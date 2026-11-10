# Street plans and construction

Enter the modern street through the regional explorer. The board west of the starting position shows the three reusable plans, the remaining free draws and the current building opportunity. The first draw is available at the board. Survey any two distinct sites to earn the other two draws. Survey credit can be banked before the first draw. After the first draw, the site sheet also allows an earned draw.

The finite deck has six possible orders. Draws always add a new plan. Requesting an opportunity is a separate action. Eligible sites are unbuilt and match at least one collected plan. Skipping removes that site from the next pool when an alternative exists. The board names every eligible site and shows the per-site probability before the request. Select one owned compatible plan, then approach the indicated plot and press E to build. Building also registers a first survey when a survey credit remains. A plot accepts one permanent installation. A plan can be used at multiple compatible sites.

| Place | Construction choices |
| --- | --- |
| West cross street | Switchable street light or pedestrian guide |
| South rear lane | Rest seat or street light |
| North rear lane | Pedestrian guide or rest seat |

A street light changes local illumination, a seat uses the existing seated camera and checked exit paths, and a guide cycles walking destinations with compass direction and straight-line distance. Installation survives re-entry. Light switches and active directions are local to the visit.

The ledger uses its own save directory and the existing bounded single-writer record format. Deck order, draw history, surveys, the next site roll, offered and accepted work, the last skipped site and installations persist independently of F5/F9. Each command proposes a complete copy and publishes it after write and readback. Damaged, stale or uncertain records block further writes until a clean reload. A failed final readback can leave a promoted record on disk. Reload resolves it before another command. Restoring a five-field workshop record affects the workshop and its visit-local objects.

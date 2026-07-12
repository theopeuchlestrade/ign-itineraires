# Restricted Asset History Rewrite

The Marianne font files and editor temporary files must not remain in Git
objects after this change is merged. Rewriting shared history is deliberately a
separate maintenance operation: pull requests cannot safely force-update
`main`, and every existing clone becomes incompatible with the rewritten refs.

## Maintenance procedure

1. Merge the improvement pull request and suspend pushes to the repository.
2. Ask collaborators to commit or export all local work.
3. Run the purge from a fresh mirror clone:

   ```sh
   git clone --mirror git@github.com:theopeuchlestrade/ign-itineraires.git \
     ign-itineraires-purge.git
   cd ign-itineraires-purge.git
   sh /path/to/ign-itineraires/scripts/purge_restricted_history.sh
   ```

4. Inspect the rewritten refs and confirm that the verification printed no
   restricted paths.
5. Temporarily allow force updates to protected branches, then publish all
   rewritten branches and tags:

   ```sh
   git push --force --mirror origin
   ```

6. Restore branch protection immediately and remove old release artifacts or
   caches that contain the fonts.
7. Ask every collaborator to delete their old clone and clone the repository
   again. Do not merge or fetch old branches into the rewritten repository.

GitHub may retain unreachable objects for a limited time. If immediate removal
from cached views is required, contact GitHub Support after the force update.

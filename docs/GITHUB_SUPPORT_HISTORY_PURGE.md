# GitHub Support request — sensitive data removal

Repository: https://github.com/leoo1992/hero-app-back

Hello GitHub Support,

I have rewritten the repository history to remove sensitive environment configuration that was committed in the past. The affected historical commits include:

- 13be88e — "exposed .env"
- f7da026 — "exposed dot env"
- d3bc39e — "remove tracked environment file"

The current branch history has been rewritten and the cleaned refs have been force-pushed. Please help purge cached views and any retained references to the affected commits and sensitive file contents from GitHub's cached pages and internal views, where possible.

I am treating all potentially exposed credentials as compromised and will rotate them independently of the history rewrite. Please let me know if any additional repository identifiers or verification steps are required.

Thank you.

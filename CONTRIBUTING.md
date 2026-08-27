# Contributing

Issues and pull requests are welcome.

Before submitting a change:

1. run `bash -n docker-entrypoint.sh`;
2. validate `.gitlab-ci.yml` and `.github/workflows/*.yml`;
3. build the image with `docker build -t devin-in-a-box:test .`;
4. verify that no credentials, personal data, or generated conversation files
   are included; and
5. explain any security or compatibility tradeoffs in the pull request.

Never use real Devin credentials in a public CI job or test fixture.

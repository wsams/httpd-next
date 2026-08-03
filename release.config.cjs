module.exports = {
  branches: ['main'],
  plugins: [
    '@semantic-release/commit-analyzer',
    '@semantic-release/release-notes-generator',
    '@semantic-release/github',
    [
      '@semantic-release/exec',
      {
        publishCmd:
          'PUSH=true FLOAT_BASE=latest FLOAT_PHP=php FLOAT_PYTHON=python FLOAT_GO=go FLOAT_STACK=stack ./scripts/build-images.sh ${nextRelease.version}',
      },
    ],
  ],
};

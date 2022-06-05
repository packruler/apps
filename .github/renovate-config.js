module.exports = {
  dryRun: true,
  username: 'truecharts-bot',
  gitAuthor: 'truecharts-bot <bot@truecharts.org>',
  onboarding: false,
  platform: 'github',
  repositories: [
    'packruler/apps',
  ],
  packageRules: [
    {
      description: 'lockFileMaintenance',
      matchUpdateTypes: [
        'pin',
        'digest',
        'patch',
        'minor',
        'major',
        'lockFileMaintenance',
      ],
      dependencyDashboardApproval: false,
      stabilityDays: 0,
    },
  ],
};

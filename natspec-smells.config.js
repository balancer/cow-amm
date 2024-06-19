/**
 * List of supported options: https://github.com/defi-wonderland/natspec-smells?tab=readme-ov-file#options
 */

/** @type {import('@defi-wonderland/natspec-smells').Config} */
module.exports = {
  enforceInheritdoc: false,
  include: 'src/**/*.sol',
  exclude: 'src/contracts/B(Num|Const).sol',
};

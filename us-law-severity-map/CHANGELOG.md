# Changelog

All notable changes to this project will be documented in this file.

## [3.0.0] - 2025-10-29

### Added - AWS Deployment & Infrastructure

- **AWS Infrastructure**: Complete S3 + CloudFront deployment with Terraform
- **GitHub Actions Workflows**:
  - `terraform-pr-plan.yml` - Automatic plan on pull requests
  - `terraform-pr-apply.yml` - Manual apply with full control
  - `deploy-to-s3.yml` - Website deployment automation
  - `terraform-destroy.yml` - Safe infrastructure teardown
- **Branch Protection**: Requires successful Terraform Apply before merge
- **State Management**: S3 backend with DynamoDB locking
- **Documentation**:
  - Complete workflow guides and comparisons
  - AWS cost analysis (~$1-5/month)
  - Step-by-step deployment instructions
  - Branch protection setup script

### Changed

- Consolidated workflows: Removed duplicate/unsafe workflows (7 → 4)
- Simplified documentation: 3 separate docs → 2 comprehensive guides
- Updated README with complete AWS deployment section

### Security

- Manual apply workflow prevents accidental infrastructure changes
- Branch protection blocks merge without successful apply
- Complete audit trail of all infrastructure changes
- Terraform state locking prevents concurrent modifications

## [2.0.0] - 2025-10-29

### Added - Interactive Visualization

- Interactive click-to-zoom functionality for all 50 states
- Professional statistics panel with comprehensive data overlay
- Crime statistics: murder rates, gun deaths, traffic fatalities (per 100k)
- Population and incarceration rate data for each state
- Plotly-based interactive visualization with smooth animations
- US average comparisons for crime statistics
- Close button and double-click reset functionality
- Standalone HTML export with offline functionality

### Changed

- Migrated from matplotlib to Plotly for advanced interactivity
- Hover now shows only state names; detailed stats appear on click
- Converted all text from Portuguese to English
- Improved zoom centering with state-specific coordinates
- Enhanced color gradient and visual design

### Fixed

- JSON parsing errors in JavaScript
- Event handling for click interactions
- Map centering when zooming to states

## [1.0.0] - 2025-10-28

### Added

- Initial release with static choropleth map
- Law severity scoring system (0-100 scale)
- Death penalty status for all 50 states
- Automatic US Census Bureau shapefile download
- Basic matplotlib visualization
- Documentation and README

---

**Current Version**: 2.0.0  
**Repository**: https://github.com/raolivei/us-law-severity-map

# 🌾 Bitcoin-Backed Microinsurance for Farmers

A parametric insurance smart contract built on Stacks that automatically provides payouts to farmers based on weather oracle data, protecting against droughts and floods.

## 🚀 Overview

This smart contract enables small farmers to purchase affordable insurance coverage against weather-related crop failures. Using real-time weather data from authorized oracles, the contract automatically triggers payouts when rainfall conditions indicate drought or flood scenarios.

## ✨ Features

- 🔐 **Secure Policy Creation**: Farmers can create insurance policies with customizable coverage and duration
- 🌧️ **Weather Oracle Integration**: Real-time weather data triggers automatic payouts
- 💰 **STX-Backed Coverage**: Policies are backed by Stacks (STX) tokens for reliable payouts
- 📍 **Location-Based**: GPS coordinates ensure accurate weather monitoring for specific farm locations
- ⚡ **Instant Claims**: Automatic payout when weather conditions meet claim criteria (drought ≤10mm or flood ≥200mm)
- 👨‍💼 **Multi-Policy Support**: Farmers can hold up to 50 active policies
- 📊 **Contract Analytics**: Real-time statistics on total policies, premiums, and payouts
- 🛡️ **Emergency Controls**: Owner emergency withdraw and contract funding capabilities

## 🛠️ Contract Functions

### 📋 Public Functions

#### `create-policy`
Create a new insurance policy for your farm.
```clarity
(create-policy premium coverage duration lat lng)
```
- `premium`: Amount to pay in STX (min: 1 STX, max: 100 STX)
- `coverage`: Payout amount in STX (min: 5 STX, max: 1000 STX)
- `duration`: Policy duration in blocks (min: 144 blocks ≈ 1 day, max: 52,560 blocks ≈ 1 year)
- `lat`: Farm latitude in integer format (e.g., 40712800 for 40.7128°N)
- `lng`: Farm longitude in integer format (e.g., -74006000 for -74.0060°W)

#### `claim-payout`
Claim insurance payout when weather conditions trigger coverage.
```clarity
(claim-payout policy-id)
```
**Triggers automatically when:**
- Drought: Rainfall ≤ 10mm during policy period
- Flood: Rainfall ≥ 200mm during policy period

#### `cancel-policy`
Cancel a policy before it starts (50% premium refund).
```clarity
(cancel-policy policy-id)
```

#### `submit-weather-data`
Submit weather data (authorized oracles only).
```clarity
(submit-weather-data lat lng rainfall temperature)
```

#### `fund-contract`
Add funds to the contract (anyone can contribute).
```clarity
(fund-contract amount)
```

### 👁️ Read-Only Functions

#### `get-policy`
Retrieve policy details by ID.
```clarity
(get-policy policy-id)
```

#### `get-user-policy-count`
Get number of policies for a user.
```clarity
(get-user-policy-count user-principal)
```

#### `get-contract-stats`
View contract statistics.
```clarity
(get-contract-stats)
```

#### `get-weather-data`
Get weather data for specific location and block height.
```clarity
(get-weather-data lat lng report-height)
```

#### `is-oracle-authorized`
Check if an oracle is authorized.
```clarity
(is-oracle-authorized oracle-principal)
```

### 🔐 Owner-Only Functions

#### `authorize-oracle`
Authorize a weather oracle.
```clarity
(authorize-oracle oracle-principal)
```

#### `revoke-oracle`
Revoke oracle authorization.
```clarity
(revoke-oracle oracle-principal)
```

#### `emergency-withdraw`
Emergency fund withdrawal (owner only).
```clarity
(emergency-withdraw amount)
```

## 🌦️ Weather Triggers

The contract automatically triggers payouts when:
- **Drought Conditions**: Rainfall ≤ 10mm during policy period
- **Flood Conditions**: Rainfall ≥ 200mm during policy period
- Weather data is verified by authorized oracles
- Policy is active and hasn't been claimed or cancelled

## 📊 Policy Limits & Validation

- **Premium Range**: 1 STX to 100 STX
- **Coverage Range**: 5 STX to 1,000 STX
- **Duration Range**: 144 blocks (≈1 day) to 52,560 blocks (≈1 year)
- **Max Policies**: 50 per farmer
- **Cancellation**: Available before policy start date with 50% refund

## 🔧 Setup Instructions

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js and npm

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd Bitcoin-Backed-Microinsurance-for-Farmers
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
clarinet test
```

4. Deploy to testnet:
```bash
clarinet deploy --testnet
```

## 💡 Usage Examples

### Creating a Policy
```clarity
;; Create a 30-day drought insurance policy
;; Premium: 2 STX, Coverage: 20 STX, Duration: 4320 blocks (≈30 days)
;; Farm location: lat 40.7128, lng -74.0060 (New York area)
(contract-call? .btc-backed-mf create-policy u2000000 u20000000 u4320 40712800 -74006000)
```

### Checking Policy Details
```clarity
;; Check details of policy #1
(contract-call? .btc-backed-mf get-policy u1)
```

### Claiming Payout
```clarity
;; Claim payout for policy #1 (if weather conditions met)
(contract-call? .btc-backed-mf claim-payout u1)
```

### Authorizing Weather Oracle
```clarity
;; Authorize a weather oracle (owner only)
(contract-call? .btc-backed-mf authorize-oracle 'SP1234567890ABCDEF...)
```

### Submitting Weather Data
```clarity
;; Submit weather data (authorized oracles only)
;; Location: 40.7128, -74.0060, Rainfall: 5mm, Temperature: 25°C
(contract-call? .btc-backed-mf submit-weather-data 40712800 -74006000 u5 u25)
```

## 📈 Contract Statistics

The contract tracks:
- Total number of policies created
- Total premiums collected
- Total payouts distributed
- Current contract balance

## 🔐 Security Features

- Owner-only oracle authorization and emergency controls
- Input validation for all parameters
- Secure fund transfers using `as-contract`
- Policy claim restrictions to prevent double-spending
- Time-based policy activation and expiration
- Multi-signature oracle verification system

## 🌍 Oracle Integration

Weather oracles must be authorized by the contract owner before submitting data. This ensures data integrity and prevents malicious weather reports. Oracles submit:
- GPS coordinates (latitude/longitude)
- Rainfall measurements (in mm)
- Temperature data
- Block height timestamps

## 🚨 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | ERR_UNAUTHORIZED | Caller not authorized |
| u101 | ERR_INVALID_PARAMS | Invalid parameters provided |
| u102 | ERR_POLICY_NOT_FOUND | Policy doesn't exist |
| u103 | ERR_POLICY_EXPIRED | Policy has expired |
| u104 | ERR_POLICY_ALREADY_CLAIMED | Policy already claimed |
| u105 | ERR_INSUFFICIENT_FUNDS | Not enough funds |
| u106 | ERR_POLICY_NOT_ACTIVE | Policy is not active |
| u107 | ERR_ORACLE_NOT_AUTHORIZED | Oracle not authorized |
| u108 | ERR_WEATHER_DATA_NOT_FOUND | Weather data unavailable |
| u109 | ERR_NO_CLAIM_CONDITIONS | Weather conditions don't meet claim criteria |
| u110 | ERR_POLICY_LIMIT_REACHED | Maximum policies per user reached |
| u111 | ERR_POLICY_ALREADY_CANCELLED | Policy already cancelled |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For questions or support, please open an issue in the GitHub repository.

---

*Protecting farmers with blockchain technology* 🌾⛈️💧

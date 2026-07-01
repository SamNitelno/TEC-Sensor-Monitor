#pragma once

#include "wifi_manager.h"

#include <functional>

using ProvisioningCommitHandler = std::function<void(const DeviceConfig&)>;

void startBleProvisioning(ProvisioningCommitHandler onCommit);
void stopBleProvisioning();
void pollBleProvisioning();

# Azure CLI not compatible with alpine3.19
FROM docker.io/selenium/standalone-chrome AS build
ARG BUILD_AZP_TOKEN
ARG BUILD_AZP_URL
ARG BUILD_AZP_VERSION=1.0.0.0

ENV VSO_AGENT_IGNORE="AZP_TOKEN,AZP_TOKEN_FILE"
ENV BUILD_AZP_VERSION="${BUILD_AZP_VERSION}"
ENV TARGETARCH="linux-x64"

RUN ls

USER root

RUN apt-get update
RUN apt-get upgrade -y
RUN icu="$(apt-cache search --names-only '^libicu[0-9][0-9]+$' | awk '{ print $1 }' | sort -V | tail -n 1)" \
    && test -n "$icu" \
    && echo "Installing ${icu}" \
    && apt-get install -y curl git jq "$icu" wget apt-transport-https software-properties-common
RUN apt-get install -y npm zip nodejs python3 python3-pip ffmpeg

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && az upgrade --all --yes

WORKDIR /azp/

COPY ./install.sh /azp/
COPY ./start.sh /azp/
COPY ./primedotnet.ps1 /azp/

RUN chmod +x ./install.sh \
    && chmod +x ./start.sh \
    && chmod +x ./primedotnet.ps1 \
    && chown -R seluser ./ \
    && mkdir /home/seluser/.local/share/NuGet \
    && chown -R seluser /home/seluser/.local/share/NuGet \
    && rm -rf /home/seluser/.azure \
    && mkdir /home/seluser/.azure \
    && chown -R seluser /home/seluser/.azure

# Publish PowerShell on usual /usr paths; install later fills these in
RUN ln -sfn /azp/tools/powershell /usr/share/powershell \
    && ln -sfn /azp/tools/powershell/pwsh /usr/bin/pwsh

USER seluser

ENV AGENT_TOOLSDIRECTORY="/azp/tools"
RUN mkdir /azp/tools

# Clear az cli account / cache
RUN az account clear \
    && az cache purge \
    && az bicep upgrade \
    && az version -o table

# Install .NET
ENV NUGET_PACKAGES="/azp/nuget/NUGET_PACKAGES"
ENV NUGET_HTTP_CACHE_PATH="/azp/nuget/NUGET_HTTP_CACHE_PATH"
ENV NUGET_PLUGINS_CACHE_PATH="/azp/nuget/NUGET_PLUGINS_CACHE_PATH"
ENV NUGET_SCRATCH="/azp/nuget/NUGET_SCRATCH"
ENV PATH="/azp/tools/dotnet:${PATH}"
ENV DOTNET_ROOT="/azp/tools/dotnet"
ENV DOTNET_HOST_PATH="/azp/tools/dotnet/dotnet"
RUN mkdir /azp/nuget \
    && mkdir /azp/nuget/NUGET_PACKAGES \
    && mkdir /azp/nuget/NUGET_HTTP_CACHE_PATH \
    && mkdir /azp/nuget/NUGET_PLUGINS_CACHE_PATH \
    && mkdir /azp/nuget/NUGET_SCRATCH \
    && mkdir /azp/tools/dotnet \
    && curl -Lsfo "dotnet-install.sh" https://dot.net/v1/dotnet-install.sh \
    && chmod +x "dotnet-install.sh" \
    && ./dotnet-install.sh --channel 10.0 --install-dir /azp/tools/dotnet \
    && ./dotnet-install.sh --channel 11.0 --install-dir /azp/tools/dotnet

# Install DevOps Agent
RUN export AZP_TOKEN=${BUILD_AZP_TOKEN} \
    && export AZP_URL=${BUILD_AZP_URL} \
    && ./install.sh

# Install Global tools
ENV PATH="${PATH}:/home/seluser/.dotnet/tools"
RUN dotnet tool install --global dpi \
    && dpi --version \
    && dotnet tool install --global Cake.Tool \
    && dotnet cake --info

# Install PowerShell (RID package isn't on nuget.org, fetch it from the PowerShell feed)
ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off
RUN powershell_version="$(curl -fsSL https://aka.ms/pwsh-buildinfo-stable \
        | jq -er '.ReleaseTag | ltrimstr("v")')" \
    && curl --fail --show-error --location --output "/tmp/PowerShell.Linux.x64.${powershell_version}.nupkg" \
        "https://powershellinfraartifacts-gkhedzdeaghdezhr.z01.azurefd.net/tool/${powershell_version}/PowerShell.Linux.x64.${powershell_version}.nupkg" \
    && /azp/tools/dotnet/dotnet tool install --add-source /tmp --tool-path /azp/tools/powershell --version "${powershell_version}" PowerShell.Linux.x64 \
    && rm -f "/tmp/PowerShell.Linux.x64.${powershell_version}.nupkg" \
    && chmod 755 /azp/tools/powershell/pwsh \
    && chmod 755 /azp/tools/powershell/.store/powershell.linux.x64/${powershell_version}/powershell.linux.x64/${powershell_version}/tools/*/any/pwsh \
    && find /azp/tools/powershell -iname '*.nupkg' -delete \
    && pwsh --version

# Prime .NET
RUN ./primedotnet.ps1

ENTRYPOINT ./start.sh

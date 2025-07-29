# Container.ps1 - Contenedor simple de InyecciÃ³n de Dependencias
using namespace System.Collections.Generic

class ServiceDescriptor {
    [Type]$ServiceType
    [Type]$ImplementationType
    [object]$ImplementationFactory
    [object]$ImplementationInstance
    [ServiceLifetime]$Lifetime

    ServiceDescriptor([Type]$serviceType, [Type]$implementationType, [ServiceLifetime]$lifetime) {
        $this.ServiceType = $serviceType
        $this.ImplementationType = $implementationType
        $this.Lifetime = $lifetime
    }

    ServiceDescriptor([Type]$serviceType, [ScriptBlock]$factory, [ServiceLifetime]$lifetime) {
        $this.ServiceType = $serviceType
        $this.ImplementationFactory = $factory
        $this.Lifetime = $lifetime
    }

    ServiceDescriptor([Type]$serviceType, [object]$instance) {
        $this.ServiceType = $serviceType
        $this.ImplementationInstance = $instance
        $this.Lifetime = [ServiceLifetime]::Singleton
    }
}

enum ServiceLifetime {
    Transient   # Nueva instancia cada vez
    Scoped      # Una instancia por scope
    Singleton   # Una sola instancia para toda la aplicaciÃ³n
}

class ServiceScope {
    [Dictionary[Type, object]]$ScopedInstances
    [ServiceProvider]$ServiceProvider

    ServiceScope([ServiceProvider]$provider) {
        $this.ServiceProvider = $provider
        $this.ScopedInstances = [Dictionary[Type, object]]::new()
    }

    [void] Dispose() {
        foreach ($instance in $this.ScopedInstances.Values) {
            if ($instance -is [IDisposable]) {
                $instance.Dispose()
            }
        }
        $this.ScopedInstances.Clear()
    }
}

class ServiceProvider {
    hidden [Dictionary[Type, ServiceDescriptor]]$services
    hidden [Dictionary[Type, object]]$singletonInstances
    hidden [ServiceScope]$currentScope

    ServiceProvider([Dictionary[Type, ServiceDescriptor]]$serviceDescriptors) {
        $this.services = $serviceDescriptors
        $this.singletonInstances = [Dictionary[Type, object]]::new()
    }

    [object] GetService([Type]$serviceType) {
        if (-not $this.services.ContainsKey($serviceType)) {
            return $null
        }

        $descriptor = $this.services[$serviceType]

        switch ($descriptor.Lifetime) {
            ([ServiceLifetime]::Transient) {
                return $this.CreateInstance($descriptor)
            }
            ([ServiceLifetime]::Scoped) {
                if ($null -eq $this.currentScope) {
                    throw "No hay un scope activo para servicios Scoped"
                }

                if ($this.currentScope.ScopedInstances.ContainsKey($serviceType)) {
                    return $this.currentScope.ScopedInstances[$serviceType]
                }

                $instance = $this.CreateInstance($descriptor)
                $this.currentScope.ScopedInstances[$serviceType] = $instance
                return $instance
            }
            ([ServiceLifetime]::Singleton) {
                if ($this.singletonInstances.ContainsKey($serviceType)) {
                    return $this.singletonInstances[$serviceType]
                }

                $instance = $this.CreateInstance($descriptor)
                $this.singletonInstances[$serviceType] = $instance
                return $instance
            }
        }

        return $null
    }

    [T] GetService[T]() {
        return [T]$this.GetService([T])
    }

    [object] GetRequiredService([type]$serviceType) {
        $service = $this.GetService($serviceType)
        if ($null -eq $service) {
            throw "No se pudo resolver el servicio: $($serviceType.FullName)"
        }
        return $service
    }

    [T] GetRequiredService[T]() {
        return [T]$this.GetRequiredService([T])
    }

    [ServiceScope] CreateScope() {
        return [ServiceScope]::new($this)
    }

    hidden [object] CreateInstance([ServiceDescriptor]$descriptor) {
        # Si hay una instancia predefinida, usarla
        if ($null -ne $descriptor.ImplementationInstance) {
            return $descriptor.ImplementationInstance
        }

        # Si hay un factory, usarlo
        if ($null -ne $descriptor.ImplementationFactory) {
            return & $descriptor.ImplementationFactory $this
        }

        # Crear instancia usando reflection
        $constructors = $descriptor.ImplementationType.GetConstructors()

        if ($constructors.Count -eq 0) {
            throw "No se encontraron constructores para $($descriptor.ImplementationType.FullName)"
        }

        # Usar el primer constructor (idealmente deberÃ­amos elegir el mejor)
        $constructor = $constructors[0]
        $parameters = $constructor.GetParameters()

        if ($parameters.Count -eq 0) {
            return $descriptor.ImplementationType::new()
        }

        # Resolver dependencias
        $args = @()
        foreach ($param in $parameters) {
            $paramService = $this.GetService($param.ParameterType)
            if ($null -eq $paramService) {
                throw "No se pudo resolver la dependencia: $($param.ParameterType.FullName)"
            }
            $args += $paramService
        }

        return $descriptor.ImplementationType::new($args)
    }
}

class ServiceCollection {
    hidden [List[ServiceDescriptor]]$descriptors

    ServiceCollection() {
        $this.descriptors = [List[ServiceDescriptor]]::new()
    }

    # Registrar servicio transitorio
    [ServiceCollection] AddTransient([Type]$serviceType, [Type]$implementationType) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $implementationType, [ServiceLifetime]::Transient)
        $this.descriptors.Add($descriptor)
        return $this
    }

    [ServiceCollection] AddTransient([Type]$serviceType, [ScriptBlock]$factory) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $factory, [ServiceLifetime]::Transient)
        $this.descriptors.Add($descriptor)
        return $this
    }

    # Registrar servicio scoped
    [ServiceCollection] AddScoped([Type]$serviceType, [Type]$implementationType) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $implementationType, [ServiceLifetime]::Scoped)
        $this.descriptors.Add($descriptor)
        return $this
    }

    [ServiceCollection] AddScoped([Type]$serviceType, [ScriptBlock]$factory) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $factory, [ServiceLifetime]::Scoped)
        $this.descriptors.Add($descriptor)
        return $this
    }

    # Registrar servicio singleton
    [ServiceCollection] AddSingleton([Type]$serviceType, [Type]$implementationType) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $implementationType, [ServiceLifetime]::Singleton)
        $this.descriptors.Add($descriptor)
        return $this
    }

    [ServiceCollection] AddSingleton([Type]$serviceType, [ScriptBlock]$factory) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $factory, [ServiceLifetime]::Singleton)
        $this.descriptors.Add($descriptor)
        return $this
    }

    [ServiceCollection] AddSingleton([Type]$serviceType, [object]$instance) {
        $descriptor = [ServiceDescriptor]::new($serviceType, $instance)
        $this.descriptors.Add($descriptor)
        return $this
    }

    # Construir el service provider
    [ServiceProvider] BuildServiceProvider() {
        $serviceDict = [Dictionary[Type, ServiceDescriptor]]::new()

        foreach ($descriptor in $this.descriptors) {
            # Si ya existe, el Ãºltimo registro gana
            if ($serviceDict.ContainsKey($descriptor.ServiceType)) {
                $serviceDict[$descriptor.ServiceType] = $descriptor
            } else {
                $serviceDict.Add($descriptor.ServiceType, $descriptor)
            }
        }

        return [ServiceProvider]::new($serviceDict)
    }

    # MÃ©todos helper para registro comÃºn
    [ServiceCollection] AddLogging() {
        # Cargar el sistema de logging
        . "$PSScriptRoot\..\Core\Utilities\Logger.ps1"

        $this.AddSingleton([ILogger], {
                param($provider)
                [LoggerFactory]::CreateDefaultLogger()
            })

        return $this
    }

    [ServiceCollection] AddConfiguration([string]$configPath) {
        # Cargar servicios de configuraciÃ³n
        . "$PSScriptRoot\..\Core\Services\IConfigurationService.ps1"
        . "$PSScriptRoot\..\Core\Services\ConfigurationService.ps1"

        $this.AddSingleton([IConfigurationService], {
                param($provider)
                [ConfigurationService]::new($configPath, "$env:USERPROFILE\Documents\ProcessManager\UserConfig.json")
            })

        $this.AddSingleton([Configuration], {
                param($provider)
                $configService = $provider.GetRequiredService([IConfigurationService])
                $configService.LoadConfiguration()
            })

        return $this
    }

    [ServiceCollection] AddProcessServices() {
        # Cargar servicios de procesos
        . "$PSScriptRoot\..\Core\Services\IProcessService.ps1"
        . "$PSScriptRoot\..\Core\Services\ProcessService.ps1"
        . "$PSScriptRoot\..\Infrastructure\Windows\WindowsServiceManager.ps1"

        $this.AddSingleton([IServiceManager], [WindowsServiceManager])

        $this.AddScoped([IProcessService], {
                param($provider)
                $config = $provider.GetRequiredService([Configuration])
                $serviceManager = $provider.GetRequiredService([IServiceManager])
                [ProcessService]::new($config, $serviceManager)
            })

        return $this
    }
}

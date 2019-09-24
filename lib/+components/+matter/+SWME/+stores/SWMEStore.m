classdef SWMEStore < matter.store
    % SWME is a matter store with a liquid water and a water vapor phase,
    % connected with each other through the X50Membrane P2P processor
    
    properties
    end
    
    methods
        
        function this = SWMEStore(oContainer, sName)
            
            % Parsing the overall SWME vapor volume from the parent system.
            fSWMEVaporVolume = oContainer.fSWMEVaporVolume;
            
            % Defining volume available for the liquid phase inside the
            % hollow fibers
            fSWMELiquidVolume = pi * (oContainer.fFiberInnerDiameter/2)^2 * oContainer.fFiberExposedLength * oContainer.iNumberOfFibers;
            
            fSWMEVolume = fSWMEVaporVolume + fSWMELiquidVolume;
            
            % Calling the parent class constructor
            this@matter.store(oContainer, sName, fSWMEVolume);
            
            % Creating the input struct for the findProperty() method
            tParameters = struct();
            tParameters.sSubstance       = 'H2O';
            tParameters.sProperty        = 'Density';
            tParameters.sFirstDepName    = 'Temperature';
            tParameters.fFirstDepValue   = oContainer.fInitialTemperature;
            tParameters.sPhaseType       = 'liquid';
            tParameters.sSecondDepName   = 'Pressure';
            tParameters.fSecondDepValue  = 28300;
            tParameters.bUseIsobaricData = true;
            
            fWaterDensity = this.oMT.findProperty(tParameters);
            
            fWaterMass = fWaterDensity * fSWMELiquidVolume;
            
            % Creating liquid water phase inside the hollow fibers of the
            % X50 membrane 
            oLiquidHoFiPhase = matter.phases.liquid(...
                               this,...                           % Store where the phase is located
                              'FlowPhase', ...                    % Phase name
                               struct('H2O', fWaterMass), ...     % Phase contents
                               oContainer.fInitialTemperature,... % Phase temperature
                               28300);                            % Phase pressure
            
                           
            % Calculating the mass of water we want to put into the SWME
            % volume so it is in equilibrium with the hollow fibers at the
            % initial temperature and with a closed BPV.
            
            % Calculating the mean saturation pressure inside the hollow
            % fibers in [Pa]
            fVaporPressure = this.oMT.calculateVaporPressure(oContainer.fInitialTemperature, 'H2O');
            
            % Updating the input struct for the findProperty() method
            tParameters.sPhaseType      = 'gas';
            tParameters.fSecondDepValue = fVaporPressure;
            
            % Now we can calculate the density based on the parameters
            fVaporDensity = this.oMT.findProperty(tParameters);
                           
            % Calculating the water vapor mass
            fVaporMass = fVaporDensity * fSWMEVaporVolume;
            
            % Creating the vapor phase filling the SWME around the hollow
            % fibers
            oVaporSWME = matter.phases.gas(...
                         this, ...                           % Store in which the phase is located
                        'VaporPhase', ...                    % Phase name
                         struct('H2O', fVaporMass), ...      % Phase contents
                         fSWMEVaporVolume, ...               % Phase volume
                         oContainer.fInitialTemperature);    % Phase temperature
            
            % Creating exmes for the vapor phase
            matter.procs.exmes.gas(oVaporSWME, 'VaporIn');                % vapor exiting the  X50 membrane
            matter.procs.exmes.gas(oVaporSWME, 'VaporOut');               % vapor exiting the housing to the backpressure valve
            
            % Creating exmes for the liquid water phase
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterIn');       % water entering the SWME from the inlet feed tank
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterOut');      % water exiting the SWME to the outlet feed tank
            matter.procs.exmes.liquid(oLiquidHoFiPhase, 'WaterToVapor');  % water evaporating through the membrane wall
            
            % Calculating the total membrane area based on the static
            % properties.
            fAreaPerFiber = oContainer.fFiberExposedLength * 2 * pi * oContainer.fFiberInnerDiameter / 2;
            fMembraneArea = fAreaPerFiber * oContainer.iNumberOfFibers; %#ok<NASGU>
            
            % Creating P2P processor which describes the vapor flux from
            % the inside of the hollow fibers, through the hydrophobic
            % membrane wall, to the inside of the SWME housing
            eval([this.oMeta.ContainingPackage.ContainingPackage.Name, '.procs.X50Membrane(this, ''X50Membrane'', ''FlowPhase.WaterToVapor'', ''VaporPhase.VaporIn'', fMembraneArea);']);
        end
    end
end


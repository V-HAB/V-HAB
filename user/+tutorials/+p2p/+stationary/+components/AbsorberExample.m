classdef AbsorberExample < matter.procs.p2ps.stationary
    %ABSORBEREXAMPLE An example for a p2p processor implementation
    %   The actual logic behind the absorbtion behavior is not based on any
    %   specific physical system. It is just implemented in a way to
    %   demonstrate the use of p2p processors
    
    properties (SetAccess = protected, GetAccess = public)
        % Ratio of actual loading and maximum load
        arLoadingRatio;
        
        % Parameter to define the speed of adsorption for the linear
        % driving force equation
        fLinearDrivingForceParameter = 1e-3; % s
    end
    
    
    methods
        function this = AbsorberExample(oStore, sName, sPhaseIn, sPhaseOut, fLinearDrivingForceParameter)
            % AbsorberExample class definition. The required inputs are
            % the basic inputs for any P2P:
            % oStore:   a valid store object from V-HAB (in your system use
            %           this.toStores.XXX and replace XXX with the desired
            %           store name)
            % sName:    Name for this P2P as a string e.g. 'Absorber'
            % sPhaseIn: Either a string with 'StoreName.ExMeName' format or
            %           a phase object. This phase will be accesible from
            %           the P2P as this.oIn.oPhase
            % sPhaseOut:Either a string with 'StoreName.ExMeName' format or
            %           a phase object. This phase will be accesible from
            %           the P2P as this.oOut.oPhase
            %
            % Optional Inputs:
            % fLinearDrivingForceParameter: Parameter for how quick the
            %                               adsorption process is in seconds.
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseIn, sPhaseOut);
            
            % If the optional input for the linear driving force parameter
            % is provided, overwrite the corresponding property
            if nargin > 4
                this.fLinearDrivingForceParameter = fLinearDrivingForceParameter;
            end
        end
    end
    
    methods (Access = protected)
        function update(this)
            
            % Get the partial pressure of the gas phase to which the P2P is
            % connected:
            afPP = this.oIn.oPhase.afPP;
            
            % Whenever something is accessed multiple times, it is usually
            % faster to store a local reference to it. In this case we
            % store the adsorber phase, which in this case is on the out
            % exme:
            oAdsorberPhase = this.oOut.oPhase;
            
            % Now we use the matter table function to calculate the
            % equilibrium loading of the filter. The equilibrium loading is
            % the theoretical maximum which can be adsorbed at the current
            % pressure and temperature conditions. Here Zeolite13X is used
            % to filter H2O and CO2. For more information on the adsorption
            % process see e.g. table 1 and equation 11 from the publication
            % "Additional Developments in Atmosphere Revitalization
            % Modeling and Simulation" 2013, R. Coker et. al. DOI:
            % 10.2514/6.2013-3455
            afEquilibriumLoading = this.oMT.calculateEquilibriumLoading(oAdsorberPhase.afMass, afPP, oAdsorberPhase.fTemperature);
            
            % Now we calculate the current loading, which means how much
            % mass is adsorbed divided with the current adsorbent masses:
            afLoading = oAdsorberPhase.afMass / sum(oAdsorberPhase.afMass(this.oMT.abAbsorber));
            
            % Just for information purposes we write the current ratio
            % between the actual loading and the equilibrium loading into
            % the property
            this.arLoadingRatio = afLoading ./ afEquilibriumLoading;
            
            % We use a linear driving force approach to calculate the
            % adsorption flowrates. See equation 6 from the above source
            % with DOI: 10.2514/6.2013-3455
            afAdsorptionFlowrates = this.fLinearDrivingForceParameter .* (afEquilibriumLoading - afLoading);
            
            % Desorption would require a seperate handling. For a realistic
            % implementation of the adsorption process, view the CDRA
            % library model! Therefore we set any negative flowrates to 0:
            afAdsorptionFlowrates(afAdsorptionFlowrates < 0) = 0;
            
            % To save calculation time (since we require this sum twice) we
            % store the sum of the adsorption flowrates in a variable
            fFlowRate = sum(afAdsorptionFlowrates);
            
            if fFlowRate ~= 0
                % Since a P2P is derived from branches (or more precisly
                % flows), which have a flowrate and a vector containing the
                % partial mass ratios within this flowrate, the P2P requires
                % the same inputs. Therefore, we have to calculate the partial
                % mass ratios within the overall flowrate, which can be done
                % using the following equation:
                arExtractPartials = afAdsorptionFlowrates ./ fFlowRate;
            else
                arExtractPartials = zeros(1, this.oMT.iSubstances);
            end

            % Now we write the flowrate and partial mass ratios to the P2P
            % which are then set as the this.fFlowRate and
            % this.arPartialMass values.
            this.setMatterProperties(fFlowRate, arExtractPartials);
        end
    end
end
classdef gas < matter.phases.flow.flow
    %% gas_flow_node
    % A gas phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    properties (Constant)
        % State of matter in phase (e.g. gas, liquid, solid)
        sType = 'gas';
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Partial pressures in Pa
        afPP;
        
        % Substance concentrations in ppm
        afPartsPerMillion;
        
        % Relative humidity in the phase, see this.update() for details on
        % the calculation.
        rRelHumidity;
    end
    
    methods
        function this = gas(oStore, sName, tfMasses, fVolume, fTemperature)
            %% gas flow node constructor
            % 
            % creates a new gas flow node which is modelled as containing
            % no mass. The fMass property of the phase must still be
            % present for implementation purposes, but it will not change
            % from it's initial value.
            % Ideally a flow node is used together with a multibranch
            % solver to calculate the pressure of the phase as flow nodes
            % are considered very small phases.
            %
            % Required Inputs:
            % oStore        : Name of parent store
            % sName         : Name of phase
            % tfMasses      : Struct containing mass value for each species
            % fVolume       : Just an informative value, as it is not
            %                 actually used in calculations
            % fTemperature  : Temperature of matter in phase
            
            this@matter.phases.flow.flow(oStore, sName, tfMasses, fVolume, fTemperature);
            
            this.fVirtualPressure = this.fMass * this.oMT.Const.fUniversalGas * this.fTemperature / (this.fMolarMass * this.fVolume);
            [ this.afPP, this.afPartsPerMillion ] = this.oMT.calculatePartialPressures(this);
            
        end
    end
        
    methods (Access = protected)
        function this = update(this)
            %% gas flow node update
            %
            % performs the normal matter phase update but additionally
            % calculates the current partial pressures and relative
            % humidity
            update@matter.phase(this);
            
            if this.oTimer.iTick > 0
                % to ensure that flow phases set the correct values and do
                % not confuse the user, a seperate calculation for them is
                % necessary
                afPartialMassFlow_In    = zeros(this.iProcsEXME, this.oMT.iSubstances);
                
                for iExme = 1:this.iProcsEXME
                    fFlowRate = this.coProcsEXME{iExme}.iSign * this.coProcsEXME{iExme}.oFlow.fFlowRate;
                    if fFlowRate > 0
                        afPartialMassFlow_In(iExme,:)   = this.coProcsEXME{iExme}.oFlow.arPartialMass .* fFlowRate;
                    end
                end
                % See ideal gas mixtures for information on this
                % calculation: "Ideally the ratio of partial pressures
                % equals the ratio of the number of molecules. That is, the
                % mole fraction of an individual gas component in an ideal
                % gas mixture can be expressed in terms of the component's
                % partial pressure or the moles of the component"
                afCurrentMolsIn     = (sum(afPartialMassFlow_In,1) ./ this.oMT.afMolarMass);
                arFractions         = afCurrentMolsIn ./ sum(afCurrentMolsIn);
                afPartialPressure   = arFractions .*  this.fPressure;
                
                afPartialPressure(isnan(afPartialPressure)) = 0;
                afPartialPressure(afPartialPressure < 0 ) = 0;
                
                this.afPP = afPartialPressure;
                
                if this.afPP(this.oMT.tiN2I.H2O)
                    % calculate saturation vapour pressure [Pa];
                    fSaturationVapourPressure = this.oMT.calculateVaporPressure(this.fTemperature, 'H2O');
                    % calculate relative humidity
                    this.rRelHumidity = this.afPP(this.oMT.tiN2I.H2O) / fSaturationVapourPressure;
                else
                    this.rRelHumidity = 0;
                end
                
            else
                this.fMassToPressure = 0;
                this.afPP = zeros(1,this.oMT.iSubstances);
                this.rRelHumidity = 0;
            end
        end
    end
end


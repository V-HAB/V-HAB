classdef gas_flow_node < matter.phases.flow_node
    %% gas_flow_node
    % A gas phase that is modelled as containing no matter. 
    
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
        function this = gas_flow_node(oStore, sName, varargin)
            this@matter.phases.flow_node(oStore, sName, varargin{:});
            
        end
    end
        
    methods (Access = protected)
        function this = update(this)
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
                this.fPressure = 0;
                this.afPP = zeros(1,this.oMT.iSubstances);
                this.rRelHumidity = 0;
            end
        end
    end
end


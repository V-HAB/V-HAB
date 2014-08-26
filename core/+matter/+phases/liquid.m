classdef liquid < matter.phase
    %LIQUID Describes a volume of liquid
    %   Detailed explanation goes here
    %
    %TODO
    %   - support empty / zero volume (different meanings?)
    
    properties (SetAccess = protected, GetAccess = public)
        % Phase type (for matter table etc)
        sType = 'liquid';
        
        fVolume;                % Volume in m^3
        
        % Pressure in Pa
        % the pressure in the tank without the influence of gravity or
        % acceleration even if these effects exist
        fPressure;
        
        fDynamicViscosity;      % Dynamic Viscosity in Pa*s
        
        fLastUpdateLiquid = 0;
        
    end
    
    methods
        % oStore    : Name of parent store
        % sName     : Name of phase
        % tfMasses  : Struct containing mass value for each species
        % fVolume   : Volume of the phase
        % fTemp     : Temperature of matter in phase
        
        %TO DO: The parent class requires that the liquid phase definition
        %has fPressure as input but since density, temperature and pressure
        %are not independent it is not allowed to set all three. Therefore
        %the unused parameter fPressure exists here but the pressure is
        %actually calculated through the correlation.
        function this = liquid(oStore, sName, tfMasses, fVolume, fTemp, fPressure)
            this@matter.phase(oStore, sName, tfMasses, fTemp);
            
            this.fVolume  = fVolume;
            this.fTemp = fTemp;
            this.fPressure = fPressure;
            
            %TO DO make dependant on matter table
            %values for water
            %density at one fixed datapoint
            fFixDensity = 998.21;        %g/dm�
            %temperature for the fixed datapoint
            fFixTemperature = 293.15;           %K
            %Molar Mass of the compound
            fMolMassH2O = 18.01528;       %g/mol
            %critical temperature
            fCriticalTemperature = 647.096;         %K
            %critical pressure
            fCriticalPressure = 220.64*10^5;      %N/m� = Pa

            %boiling point normal pressure
            fBoilingPressure = 1.01325*10^5;      %N/m� = Pa
            %normal boiling point temperature
            fBoilingTemperature = 373.124;      %K
                
            this.fDensity = this.oStore.LiquidDensity(this.fTemp,...
                            this.fPressure, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
            
            this.fMass = this.fDensity*this.fVolume;
                        
            %TODO see .update(), also called from matter.phase constructor!
            %this.update();
        end
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fVolume', fVolume);
            this.fDensity = this.fMass / this.fVolume;
            
            %fix matter values required to use the correlations for
            %density and pressure. 

            %TO DO make dependant on matter table
            %values for water
            %density at one fixed datapoint
            fFixDensity = 998.21;        %g/dm�
            %temperature for the fixed datapoint
            fFixTemperature = 293.15;           %K
            %Molar Mass of the compound
            fMolMassH2O = 18.01528;       %g/mol
            %critical temperature
            fCriticalTemperature = 647.096;         %K
            %critical pressure
            fCriticalPressure = 220.64*10^5;      %N/m� = Pa

            %boiling point normal pressure
            fBoilingPressure = 1.01325*10^5;      %N/m� = Pa
            %normal boiling point temperature
            fBoilingTemperature = 373.124;      %K
                
            this.fPressure = this.oStore.LiquidPressure(this.fTemp,...
                            this.fDensity, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
            
            return;
            %TODO with events:
            this.trigger('set.fVolume', struct('fVolume', fVolume, 'setAttribute', @this.setAttribute));
            % So events can just set everything they want ...
            % Or see human, events return data which is processed here??
            % What is several events are registered? Different types of
            % volume change etc ...? Normally just ENERGY should be
            % provided to change the volume, and the actual change in
            % volume is returned ...
        end
        
        function bSuccess = setPressure(this, fPressure)
            % Changes the pressure of the phase.
            %
            % Ideally, I would like to set the initial pressure only once, 
            % maybe in the branch?
            %
            % TODO need some kind of check function here, possibly through
            % matter.table to make sure the pressure isn't so low, that a
            % phase change to gas takes place
            
            bSuccess = this.setParameter('fPressure', fPressure);
            %Get new Density for new pressure
            %TO DO make dependant on matter table
            %values for water
            %density at one fixed datapoint
            fFixDensity = 998.21;        %g/dm�
            %temperature for the fixed datapoint
            fFixTemperature = 293.15;           %K
            %Molar Mass of the compound
            fMolMassH2O = 18.01528;       %g/mol
            %critical temperature
            fCriticalTemperature = 647.096;         %K
            %critical pressure
            fCriticalPressure = 220.64*10^5;      %N/m� = Pa

            %boiling point normal pressure
            fBoilingPressure = 1.01325*10^5;      %N/m� = Pa
            %normal boiling point temperature
            fBoilingTemperature = 373.124;      %K
                
            this.fDensity = this.oStore.LiquidDensity(this.fTemp,...
                            this.fPressure, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                            fCriticalPressure, fBoilingPressure, fBoilingTemperature);
            this.fMass = this.fDensity*this.fVolume;
                        
                        
            return;
            %TODO with events:
            this.trigger('set.fPressure', struct('fPressure', fPressure, 'setAttribute', @this.setAttribute));
            % So events can just set everything they want ...
            % Or see human, events return data which is processed here??
            % What is several events are registered? Different types of
            % volume change etc ...? Normally just ENERGY should be
            % provided to change the volume, and the actual change in
            % volume is returned ...
        end
        
        function bSuccess = setMass(this, fMass)

            bSuccess = this.setParameter('fMass', fMass);
            this.fDensity = this.fMass / this.fVolume;
  
            return;
        end
        
        function bSuccess = setTemp(this, fTemp)

            bSuccess = this.setParameter('fTemp', fTemp);
            this.fDensity = this.fMass / this.fVolume;
            
            return;
        end

        function this = update(this)
            update@matter.phase(this);
            
            %TODO coeff m to p: also in fluids, plasma. Not solids, right?
            %     calc arPPs, rel humidity, ...
            %
            % Check for volume not empty, when called from constructor
            %TODO change phase contructor, don't call .update() directly?
            %     Or makes sense to always check for an empty fVolume? Does
            %     it happen that fVol is empty, e.g. gas solved in fluid?
            if ~isempty(this.fVolume) && this.fLastUpdateLiquid ~= this.oStore.oTimer.fTime && this.oStore.iIncompressible == 0
                
                %fix matter values required to use the correlations for
                %density and pressure. 
                
                %TO DO make dependant on matter table
                %values for water
                %density at one fixed datapoint
                fFixDensity = 998.21;        %g/dm�
                %temperature for the fixed datapoint
                fFixTemperature = 293.15;           %K
                %Molar Mass of the compound
                fMolMassH2O = 18.01528;       %g/mol
                %critical temperature
                fCriticalTemperature = 647.096;         %K
                %critical pressure
                fCriticalPressure = 220.64*10^5;      %N/m� = Pa

                %boiling point normal pressure
                fBoilingPressure = 1.01325*10^5;      %N/m� = Pa
                %normal boiling point temperature
                fBoilingTemperature = 373.124;      %K
                
                fDensity = this.fMass/this.fVolume;
                this.fPressure = this.oStore.LiquidPressure(this.fTemp,...
                                fDensity, fFixDensity, fFixTemperature, fMolMassH2O, fCriticalTemperature,...
                                fCriticalPressure, fBoilingPressure, fBoilingTemperature);
                this.fLastUpdateLiquid = this.oStore.oTimer.fTime;            
            end
            for k = 1:length(this.coProcsEXME)
                this.coProcsEXME{1, k}.update();
            end
        end
    end
    
    %% Protected methods, called internally to update matter properties %%%
    methods (Access = protected)
        function setAttribute(this, sAttribute, xValue)
            % Internal helper, see @matter.phase class.
            %
            %TODO throw out, all done with events hm?
            
            this.(sAttribute) = xValue;
        end
    end
    
end


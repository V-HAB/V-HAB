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
        fPressure;              % Pressure in Pa
        
    end
    
    methods
        % oStore    : Name of parent store
        % sName     : Name of phase
        % tfMasses  : Struct containing mass value for each species
        % fVolume   : Volume of the phase
        % fTemp     : Temperature of matter in phase
        
        function this = liquid(oStore, sName, tfMasses, fVolume, fTemp)
            this@matter.phase(oStore, sName, tfMasses, fTemp);
            
            this.fVolume  = fVolume;
            this.fDensity = this.fMass / this.fVolume;
            
            %TODO see .update(), also called from matter.phase constructor!
            %this.update(0);
        end
        
        function bSuccess = setVolume(this, fVolume)
            % Changes the volume of the phase. If no processor for volume
            % change registered, do nothing.
            
            bSuccess = this.setParameter('fVolume', fVolume);
            
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
        
        function this = update(this, fTimeStep)
            update@matter.phase(this, fTimeStep);
            
            %TODO coeff m to p: also in fluids, plasma. Not solids, right?
            %     calc arPPs, rel humidity, ...
            %
            
            % Check for volume not empty, when called from constructor
            %TODO change phase contructor, don't call .update() directly?
            %     Or makes sense to always check for an empty fVolume? Does
            %     it happen that fVol is empty, e.g. gas solved in fluid?
            if ~isempty(this.fVolume)
                % ?
            end
        end
    end
    
end


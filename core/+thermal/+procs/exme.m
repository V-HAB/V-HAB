classdef exme < base
    %EXME extract/merge processor
    %   Extracts thermal energy from and merges thermal energy into a phase.
    
    properties (SetAccess = private, GetAccess = public)
        % Capacity the exme belongs to
        oCapacity;
        
        % Matter table
        oMT;
        
        % Timer
        oTimer;
        
        % Name of processor. If 'default', several MFs can be connected
        sName;
        
        % Connected thermal branch
        oBranch;
        
        % the sign decides whether a positive heat flow of the asscociated
        % branch respects a positive heat flow for the asscociated
        % capacity. E.g. the left exme in the branch definition has a
        % positive iSign, while the right exme has a negative iSign
        iSign;
        
        % In the thermal network the exmes have a heat flow property
        % because thermal energy that is transported massbound always is in
        % the direction of the mass transfer. The heatflow only respects
        % the energy change that comes from the temperature difference of
        % that transfer, and is only added to the respective exme of the
        % receiving side. Therefore, in the thermal network the two exmes
        % of a branch do not necessarily have the same heat flow (only for
        % massbound transfer). The reduction/increase in thermal energy
        % from increasing or decreasing mass is handled by the total heat
        % capacity change
        fHeatFlow = 0;
        
        bHasBranch = false;
    end
    
    
    
    methods
        function this = exme(oCapacity, sName)
            % Constructor for the exme matter processor class.
            % oPhase is the phase the exme is attached to
            % sName is the name of the processor
            % Used to extract / merge matter from / into phases. Default
            % functionality is just merging of enthalpies based on ideal
            % conditions and extraction with the according matter
            % properties and no "side effects".
            % For another behaviour, derive from that proc and overload the
            % .extract or .merge method.
            
            this.sName  = sName;
            this.oMT    = oCapacity.oMT;
            this.oTimer = oCapacity.oTimer;
            
            oCapacity.addProcEXME(this);
            
            this.oCapacity = oCapacity;
            
        end
        
        function addBranch(this, oBranch)
            % 
            
            if this.oCapacity.oPhase.oStore.oContainer.bThermalSealed
                this.throw('addBranch', 'The container to which this processors phase belongs is sealed, so no ports can be added any more.');
                
            elseif ~isempty(this.oBranch)
                this.throw('addBranch', 'There is already a branch connected to this exme! You have to create another one.');
                
            elseif ~isa(oBranch, 'thermal.branch')
                this.throw('addBranch', 'The provided branch object is not a thermal.branch!');
            end
            
            this.oBranch = oBranch;
            
            if oBranch.coExmes{1} == this
                this.iSign = -1;
            else
                this.iSign = 1;
            end
            
            this.bHasBranch = true;
        end
        
        function setHeatFlow(this, fHeatFlow)
            this.fHeatFlow = fHeatFlow;
        end
    end
end
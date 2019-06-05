classdef exme < base
    %EXME extract/merge processor
    %   Extracts thermal energy from and merges thermal energy into a capacity.
    
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
        
        % In the thermal network the exmes have a heat flow property which
        % corresponds to the thermal energy taken from the capacity (if
        % fHeatFlow * iSign is negative) or added to the capacity (if
        % fHeatFlow * iSign is positive).
        %
        % For thermal energy that is transported as mass the heatflow only
        % respects the energy change that comes from the temperature
        % difference of that transfer, and is only added to the respective
        % exme of the receiving side. Therefore, in the thermal network the
        % two exmes of a branch do not necessarily have the same heat flow
        % (only for massbound transfer). The reduction/increase in thermal
        % energy from increasing or decreasing mass is handled by the total
        % heat capacity change instead and doing it through the exmes as
        % well would result in inconsitencies
        fHeatFlow = 0;
    end
    
    
    
    methods
        function this = exme(oCapacity, sName)
            % Constructor for the exme thermal processor class. oPhase is
            % the phase the exme is attached to sName is the name of the
            % processor Used to extract / merge thermal energy from / into
            % capacities. Default functionality is just merging of
            % enthalpies based on ideal conditions and extraction with the
            % according matter properties and no "side effects". For
            % another behaviour, derive from that proc and overload the
            % .extract or .merge method.
            
            this.sName  = sName;
            this.oMT    = oCapacity.oMT;
            this.oTimer = oCapacity.oTimer;
            
            oCapacity.addProcEXME(this);
            
            this.oCapacity = oCapacity;
            
        end
        
        function addBranch(this, oBranch)
            % Assigning a branch to this exme
            
            % Checking if the container is already sealed
            if this.oCapacity.oPhase.oStore.oContainer.bThermalSealed
                this.throw('addBranch', 'The container to which this processors phase belongs is sealed, so no ports can be added any more.');
                
            % Checking if we already have a branch. If this exme is being
            % connected to an interface branch, then the left side branch
            % in coBranches of our current branch should be equal to the
            % one we are connecting to. Differently put, we are on the
            % supersystem, the branch that is currently connected to us is
            % going to be a stub and we are supposed to be connected to the
            % branch originating in the subsystem. For this reason we have
            % to allow oBranch to be overwritten here. 
            elseif ~isempty(this.oBranch) && ~(oBranch == this.oBranch.coBranches{1})
                this.throw('addBranch', 'There is already a branch connected to this exme! You have to create another one.');
            
            % Checking if we have a thermal branch or not. 
            elseif ~isa(oBranch, 'thermal.branch')
                this.throw('addBranch', 'The provided branch object is not a thermal.branch!');
            end
            
            this.oBranch = oBranch;
            
            % If this is the left side exme, a positive flow means energy
            % is taken from the connected capacity. Therefore the sign for
            % this exme is set to -1 for this case
            if oBranch.coExmes{1} == this
                this.iSign = -1;
            else
                this.iSign = 1;
            end
        end
        
        function setHeatFlow(this, fHeatFlow)
            % Function used by the thermal solver to set the heat flow in
            % [W] for this exme
            this.fHeatFlow = fHeatFlow;
        end
    end
end
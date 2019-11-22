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
    
    properties (SetAccess = private, GetAccess = private)
        % To allow reconnection of the exme we create a property to store
        % the new capacity until the post tick reconnect operation is
        % performed. The property is set to all private, as it should not
        % be seen from outside the exme!
        oNewCapacity;
        
        % Function handle to the bindPostTick function of the timer,
        % telling the corresponding post tick to be executed
        hReconnectExme;
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
            
            % For rebinding the exme, we create a post tick call back which
            % is performed after all phase operations are performed. That
            % ensures that the phase still has a valid exme etc when it is
            % calculated but that the exme is changed before the solvers
            % are updated
            this.hReconnectExme = this.oTimer.registerPostTick(@this.reconnectExMePostTick,            'thermal',        'post_capacity_temperatureupdate');
        end
        
        function addBranch(this, oBranch)
            % Assigning a branch to this exme
            
            % Checking if the container is already sealed
            if this.oCapacity.oContainer.bThermalSealed
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
        
        function reconnectExMe(this, oNewCapacity, bMatterExmeCaller)
            %% reconnectExMe
            % This function can be used to change the phase to which the
            % exme is connect, therefore also changing the phase to which
            % the corresponding branch is connected. This function does not
            % instantly change the connection, but rather binds the
            % corresponding operation into the correct post tick location
            % to ensure a consistent simulation
            % Inputs:
            % oNewCapacity: The capacity object to which the exme should be
            %               connected afterwards
            
            if nargin < 3
                bMatterExmeCaller = false;
            end
            
            % Bind the new capacity to the property, will be set in post
            % tick function reconnectExMePostTick
            this.oNewCapacity = oNewCapacity;
            
            % tells the post tick to be executed
            this.hReconnectExme();
            
            % check if we are reconnecting a thermal branch which models
            % the heat transfer from a mass branch. If that is the case,
            % ensure that this function is called from the matter exme!
            if isa(this.oBranch.coConductors{1}, 'thermal.procs.conductors.fluidic') && ~bMatterExmeCaller
                error(['reconnecting a thermal exme which models mass bound energy transfer must be done through the matter exme! Occured while reconnecting exme', this.sName])
            end
        end
    end
    %% Internal methdos
    methods (Access = private)
        function reconnectExMePostTick(this)
            %% reconnectExMePostTick
            % This function is executed in the post tick between the phase
            % massupdated (which must be performed before the exme is
            % changed) and the branch updates (which must be performed
            % therefafter).
            
            % we check if reconnecting the ExMe would moved the
            % branch from one system to another:
            
            % the first condition for this is, that the changed exme is
            % the left exme of the branch, otherwise the system did not
            % change! (as the branch is only located in the subsystem)
            if this.oBranch.coExmes{1} == this
                % The second check is if the two phases are not located in
                % the same system.
                if this.oNewCapacity.oContainer ~= this.oCapacity.oContainer
                    % If both conditions are met, the left exme and
                    % therefore the branch were moved to a different
                    % system. In this case we have to adjust the toBranches
                    % and aoBranches properties of these systems
                    % accordingly (check for thermal performed in thermal
                    % domain)
                    error(['currently it is not possible to change the left hand exme to a phase which is located in a different system! Occured while reconnecting exme', this.sName])
                    
                end
            end
            % Store the current phase as reference
            oOldCapacity = this.oCapacity;
            
            this.oCapacity = this.oNewCapacity;
            % Now we have to remove/add the exme to the old/new phase
            oOldCapacity.removeExMe(this);
            this.oCapacity.addExMe(this);
            
            % to prevent confusion, empty the new phase property
            this.oNewCapacity = [];
            
        end
    end
end
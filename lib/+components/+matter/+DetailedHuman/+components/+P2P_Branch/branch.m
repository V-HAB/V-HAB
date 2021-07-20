classdef branch < matter.branch
    % derived matter branch which is used to implement P2P branch
    % functionality within the human model
    
    methods
        function this = branch(oContainer, xLeft, csProcs, xRight, sCustomName)
            % Calling the parent constructor
            this@matter.branch(oContainer, xLeft, csProcs, xRight, sCustomName);
            
            oContainer.addP2PBranch(this);
            
        end
        
        function createProcs(~, csProcs)
            %% Creating flow objects between the processors
            %
            % Loops through the provided f2f processors and creates flow
            % object in between all of them, so that the branch always
            % consists of ExMe, Flow, F2F, Flow, F2F, ... , F2F, Flow, ExMe
            %
            % Required Inputs:
            % csProcs:      A cell array with the names of all F2F
            %               processors as entry e.g. {'Pipe_1', 'Fan_1'}
            
            % Create flow
            if ~isempty(csProcs)
                error('P2P Branch cannot have F2fs')
            end
        end
        
    end
    
    methods (Access = protected)
        
        function sSideName = handleSide(this, sSide, xInput)
            %HANDLESIDE Does a bunch of stuff related to the left or right
            %side of a branch.
            
            % Setting an index variable depending on which side we are
            % looking at.
            switch sSide
                case 'left'
                    iSideIndex = 1;
                    
                case 'right'
                    iSideIndex = 2;
            end
            
            % The xInput input parameter can have one of three forms: 
            %   - <PartName>.<PortName>
            %   - <InterfaceName>
            %   - object handle
            %
            % The following code is there to determine which of the three
            % it is. 
            
            % If xInput is an object handle, we need to create a port for
            % that object. This will be captured in the boolean variable
            % below.
            bCreatePort = false;
            
            % If xInput is the name of an interface, this boolean variale
            % will be set to true. 
            bInterface  = false;
            
            % Check what type of variable xInput is, it can be either a
            % string or a phase object handle.
            if isa(xInput,'matter.phase') || isa(xInput,'thermal.capacity') || isa(xInput,'electrical.component') || isa(xInput,'electrical.node')
                % It's a phase object, so we set the boolean to true.
                bCreatePort = true;
            elseif ~contains(xInput, '.')
                % It's not a phase and the string provided does not contain
                % the '.' character, therfore it must be an interface name.
                bInterface  = true;
            end
            
            if bInterface
                % This side is an interface, so we only need to set the
                % abIf(iSideIndex) entry to true.
                this.abIf(iSideIndex) = true;
                
                % Checking if the interface name is already present in this
                % system. Only do this if there any branches at all, of course.
                
                if strcmp(this.sType, 'matter') || strcmp(this.sType, 'electrical')
                    sBranches = 'aoBranches';
                elseif strcmp(this.sType, 'thermal')
                    sBranches = 'aoThermalBranches';
                end

                if ~isempty(this.oContainer.(sBranches)) && any(strcmp(subsref([ this.oContainer.(sBranches).csNames ], struct('type', '()', 'subs', {{ iSideIndex, ':' }})), xInput))
                    this.throw('branch', 'An interface called ''%s'' already exists in ''%s''! Please choose a different name.', xInput, this.oContainer.sName);
                end
                
                % The side name is just the interface name for now
                sSideName = xInput;
                
                % If this is the right side of the branch, we also need to
                % set the iIfFlow property.
                if strcmp(sSide, 'right')
                    if strcmp(this.sType, 'matter')
                        iLength = length(this.aoFlows);
                    elseif strcmp(this.sType, 'thermal')
                        iLength = length(this.coConductors);
                    elseif strcmp(this.sType, 'electrical')
                        iLength = length(this.coConductors);
                    end
                    this.setIfLength(iLength);
                end
                
            else
                % This side is not an interface, so we are either starting
                % or ending a branch here. 
                
                if bCreatePort
                    [oExMe, sSideName] = this.createPorts(xInput);
                else
                    % xInput is a string containing the name of an object
                    % and a port.
                    
                    % Split to object name / port name
                    [ sObject, sExMe ] = strtok(xInput, '.');
                    
                    % Check if object exists
                    if strcmp(this.sType, 'matter') || strcmp(this.sType, 'thermal')
                        if ~isfield(this.oContainer.toStores, sObject)
                            this.throw('branch', 'Can''t find provided store %s on parent system', sObject);
                        end
                    elseif strcmp(this.sType, 'electrical')
                        if ~isfield(this.oContainer.toStores, sObject) && ~isfield(this.oContainer.toNodes, sObject)
                            this.throw('branch', 'Can''t find provided store or node %s on parent system', sObject);
                        end
                    end
                    
                    % Get a handle to the port depending on the domain 
                    if strcmp(this.sType, 'matter')
                        oExMe = this.oContainer.toStores.(sObject).getExMe(sExMe(2:end));
                        
                        % Since we will be creating a thermal branch to run
                        % in parallel with this matter branch, we need to
                        % create a thermal ExMe that corresponds to this
                        % matter ExMe.
                        thermal.procs.exme(oExMe.oPhase.oCapacity, sExMe(2:end));
                        
                    elseif strcmp(this.sType, 'thermal')
                        oExMe = this.oContainer.toStores.(sObject).getThermalExMe(sExMe(2:end));
                    elseif strcmp(this.sType, 'electrical')
                        % The object we are looking at can either be an an
                        % electrial store or an electrical node. To
                        % successfully get the port, we have to try both.
                        try
                            oExMe = this.oContainer.toNodes.(sObject).getTerminal(sExMe(2:end));
                        catch
                            oExMe = this.oContainer.toStores.(sObject).getTerminal(sExMe(2:end));
                        end
                        
                    end
                    
                    % The side name is of the format
                    % <StoreName>__<PortName>, so we just need to do some
                    % replacing in the xInput variable.
                    sSideName = strrep(xInput, '.', '__');
                end
                
                if strcmp(this.sType, 'matter') || strcmp(this.sType, 'electrical')
                    % We create branches from left to right. If this is a
                    % left side, we need to create the first flow object.
                    % If this is a right side, we can just use the last
                    % flow object in the aoFlows property.
                    switch sSide
                        case 'left'
                            % Create a flow
                            if strcmp(this.sType, 'matter')
                                oFlow = components.matter.DetailedHuman.components.P2P_Branch.flow(this);
                            elseif strcmp(this.sType, 'electrical')
                                oFlow = electrical.flow(this);
                                
                            end

                            this.setFlows(oFlow);
                            
                        case 'right'
                            % It may be the case that a branch has no flow
                            % objects if there are no f2f processors and
                            % this branch has an interface on the left side
                            % or if it is a pass-through branch. The latter
                            % case will cause an error later on when the
                            % subsystem is connected. The former case is
                            % okay as long as the solver used on this
                            % branch can handle that.
                            if ~isempty(this.aoFlows)
                                oFlow = this.aoFlows(end);
                            else
                                oFlow = [];
                            end

                    end

                    % ... and add flow, if there is one.
                    if ~isempty(oFlow)
                        oExMe.addFlow(oFlow);
                    end
                end
                % Add port to the coExmes property
                this.coExmes{iSideIndex} = oExMe;
                
                if strcmp(this.sType, 'electrical')
                    % Add the terminal to the coTerminals property
                    this.setTerminal(oExMe, iSideIndex);
                end
                
                if strcmp(this.sType, 'thermal')
                    % Add the branch to the exmes of this branch
                    this.coExmes{iSideIndex}.addBranch(this);
                end
                
            end
        end
        
        function [oExMe, sSideName] = createPorts(this, xInput)
            % This function is used to automatically generated the ExMe
            % ports required for the branch in case only phases where
            % handed to the branch definition
            
            % To automatically generate the port name, we need to
            % get the struct with ports.
            if strcmp(this.sType, 'matter')
                toPorts = xInput.toProcsEXME;
            elseif strcmp(this.sType, 'thermal')
                toPorts = xInput.oCapacity.toProcsEXME;
            elseif strcmp(this.sType, 'electrical')
                toPorts = xInput.toTerminals;
            end

            % Now we can calculate the port number
            if isempty(toPorts)
                iNumber = 1;
            else
                iNumber = numel(fieldnames(toPorts)) + 1;
            end

            % And with the port number we can create a unique port
            % name. 
            sPortName = sprintf('Port_%i',iNumber);

            if ~isempty(this.sCustomName)
                sPortName = [sPortName, '_', this.sCustomName];
            end
            % Now we can actually create the port on the object and
            % give it its name. We also set the side name,
            % depending on the domain we are in. The side name is
            % of the format <ObjectName>__<PortName> and  the
            % object can either be a matter store, a thermal
            % capacity, an electrical component or an electrical
            % node.
            if strcmp(this.sType, 'matter')
                oExMe = components.matter.DetailedHuman.components.P2P_Branch.exmes.(xInput.sType)(xInput, sPortName);
                sSideName = [xInput.oStore.sName, '__', sPortName];
            elseif strcmp(this.sType, 'thermal')
                oExMe = thermal.procs.exme(xInput.oCapacity, sPortName);
                sSideName = [xInput.oStore.sName, '__', sPortName];
            elseif strcmp(this.sType, 'electrical')
                oExMe = electrical.terminal(xInput, sPortName);
                sSideName = [xInput.sName, '__', sPortName];
            end
        end
    end
    methods (Access = {?solver.matter.base.branch, ?base.branch})
        function setFlowRate(this, fFlowRate, ~)
            %% matter branch setFlowRate
            % INTERNAL FUNCTION! The registerHandler function of
            % base.branch provides access to this function for ONE solver,
            % and only that solver is allowed to set the flowrate for the
            % branch.
            %
            % sets the flowrate for the branch and all flow objects, as
            % well as the pressures for the flow objects
            %
            % Required Inputs:
            % fFlowRate:        New flowrate for the branch in kg/s
            % afPressureDrops:  Pressure Drops produced by the f2f
            %                   processors. Negative values in this input
            %                   represent pressure rises from e.g. fans
            
            if this.abIf(1), this.throw('setFlowRate', 'Left side is interface, can''t set flowrate on this branch object'); end
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank.
            for iE = 1:2
                this.coExmes{iE}.oPhase.registerMassupdate();
            end
            
            this.afFlowRates = [ this.afFlowRates(2:end) fFlowRate ];
            
            % If sum of the last ten flow rates is < precision, set flow
            % rate to zero
            if tools.round.prec(sum(this.afFlowRates), this.oTimer.iPrecision) == 0
                fFlowRate = 0;
                
            end
            
            this.fFlowRate = fFlowRate;
            this.bOutdated = false;
            
            
            % do not Update data in flows
            
            if this.bTriggerSetFlowRateCallbackBound
                this.trigger('setFlowRate');
            end
        end
    end
end
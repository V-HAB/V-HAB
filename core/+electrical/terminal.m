classdef terminal < base
    %TERMINAL Summary of this class goes here
    %   Detailed explanation goes here
    
    %%% NOTE: Make sure, that the iSign property cannot be changed for
    %%% sources.
    
    properties
        oParent;
        iSign;
        oFlow;
        sName;
        bHasFlow = false;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        fVoltage;
    end
    
    methods
        function this = terminal(oParent, sName)
            this.oParent = oParent;
            
            % We only have to call the addTerminal() method on the parent
            % object, if it is a node object. store objects can only have
            % two terminals and they are added in the store constructor
            % directly. Nodes can have more than two nodes, so the
            % addTerminal() method is necessary. 
            if isa(oParent, 'electrical.node')
                % If a specific name is given, we'll use that, otherwise
                % the terminal gets a numeric name derived from the parent.
                if nargin > 2
                    this.sName = sName;
                else
                    % Need to do plus one here because the terminal hasn't
                    % been added yet. 
                    this.sName = ['Terminal_', num2str(length(this.oParent.aoTerminals)+1)];
                end
                
                this.oParent.addTerminal(this);
                
            end
            
        end
        
        function addFlow(this, oFlow)
            if this.oParent.bSealed
                this.throw('addFlow', 'The parent of this terminal is sealed, so no flows can be added any more.');
            
            elseif ~isempty(this.oFlow)
                this.throw('addFlow', 'There is already a flow connected to this terminal! (%s.%s) You have to create another one.', this.oParent.sName, this.sName);
            
            elseif ~isa(oFlow, 'electrical.flow')
                this.throw('addFlow', 'The provided flow object is not an electrical.flow!');
            
            elseif any(this.oFlow == oFlow)
                this.throw('addFlow', 'The provided flow object is already registered!');
            end
            
            this.oFlow = oFlow; 
            this.bHasFlow = true;
        end
        
        function setVoltage(this, fVoltage)
            %TODO Add something here that makes sure, only a node or store
            %can call this method.
            this.fVoltage = fVoltage;
        end
        
        function update(this)
            % Is called after flows are updated? So we can just get the
            % flow, look at its sign and then set ours accordingly?
        end
    end
    
end


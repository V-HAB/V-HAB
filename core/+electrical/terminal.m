classdef terminal < base
    %TERMINAL An electrical port that can be connected to stores 
    %   This class is the equivalent of an exme in the matter and thermal
    %   domains. It connects stores and nodes to flows. 
    
    properties (SetAccess = protected, GetAccess = public)
        % A reference to the terminal's parent object
        oParent;
        
        % Direction of flow through the terminal. Positive is into the
        % parent, negative is out of the parent.
        iSign;
        
        % A reference to the electrical flow object connected to this
        % terminal.
        oFlow;
        
        % A name identifying this terminal
        sName;
        
        % A boolean variable indicating if this terminal has been assigned
        % a flow yet. Used for integrity checks before running a
        % simulation.
        bHasFlow = false;
        
        % Voltage at this terminal
        fVoltage;
    end
    
    methods
        function this = terminal(oParent, sName)
            % Setting the parent object reference.
            this.oParent = oParent;
            
            % We only have to call the addTerminal() method on the parent
            % object, if it is a node object. store objects can only have
            % two terminals and they are added in the store constructor
            % directly. Nodes can have more than two terminals, so the
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
                
                % Adding the terminal to the node.
                this.oParent.addTerminal(this);
                
            end
        end
        
        function addFlow(this, oFlow)
            %ADDFLOW Assigns a flow object to this terminal
            
            % Before we start, we do some checks. First we check if the
            % terminal is already sealed.
            if this.oParent.bSealed
                this.throw('addFlow', 'The parent of this terminal is sealed, so no flows can be added any more.');
            
            % Checking if there is already a flow object assigned to this
            % terminal.
            elseif ~isempty(this.oFlow)
                this.throw('addFlow', 'There is already a flow connected to this terminal! (%s.%s) You have to create another one.', this.oParent.sName, this.sName);
            
            % Checking if the passed in object is of the correct type.
            elseif ~isa(oFlow, 'electrical.flow')
                this.throw('addFlow', 'The provided flow object is not an electrical.flow!');
            end
            
            % Now we can set the appropriate properties of this object.
            this.oFlow = oFlow; 
            this.bHasFlow = true;
        end
        
        function setVoltage(this, fVoltage)
            %SETVOLTAGE Sets the voltage property.
            this.fVoltage = fVoltage;
        end
        
    end
    
end


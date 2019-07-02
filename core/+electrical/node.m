classdef node < base
    %NODE A class describing a node in an electrical circuit diagram
    %   A node can have multiple terminals leading to and from it. It's
    %   main property is a voltage since it does not represent an actual
    %   hardware component, but rather an intersection of several traces in
    %   the circuit diagram.
    %   The flow phase in the matter domain is equivalent to the electrical
    %   node. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Current voltage at the node
        fVoltage;
        
        % An array containing references to all terminals of this node
        aoTerminals = electrical.terminal.empty();
        
        % A struct containing references to all terminals of this node
        toTerminals = struct();
        
        % Number of terminals this node has
        iTerminals;
        
        % A reference to the circuit object this node is associated with
        oCircuit;
        
        % A string acting as an identifier for a node object
        sName;
        
        % A boolean describing the state of this node. If it is sealed,
        % nothing about its configuration can be changed. 
        bSealed;
    end
    
    methods
        
        function this = node(oCircuit, sName)
            % Setting the reference to the parent circuit
            this.oCircuit = oCircuit;
            
            % Setting the name property
            this.sName = sName;
            
            % Adding this node to the ciruit.
            this.oCircuit.addNode(this);
            
        end
        
        function addTerminal(this, oTerminal)
            %ADDTERMINAL Adds a terminal to this node
            
            % Adding a reference to the end of the aoTerminals array
            this.aoTerminals(end+1) = oTerminal;
            
            % Adding a reference to the toTerminals struct.
            this.toTerminals.(oTerminal.sName) = oTerminal;
            
        end
        
        function seal(this)
            %SEAL Seals the node to prevent changes
            
            % Setting the number of terminals
            this.iTerminals = length(this.aoTerminals);
            
            % Setting the sealed property to true
            this.bSealed = true;
        end
        
        function oTerminal = getTerminal(this, sTerminalName)
            %GETTERMINAL Returns a reference to a specific terminal of the node
            
            % We try to access it by its name in the toTerminals struct. If
            % it doesn't exist, we throw an error. 
            try 
                oTerminal = this.toTerminals.(sTerminalName);
            catch
                if ~isfield(this.toTerminals, sTerminalName)
                    this.throw('getTerminal','There is no terminal ''%s'' on node %s.', sTerminalName, this.sName);
                end
            end
        end
        
        function createTerminals(this, iNumberOfTerminals)
            %CREATETERMINALS Helper function to create more than one terminal at the same time
            
            for iI = 1:iNumberOfTerminals
                electrical.terminal(this);
            end
        end
        
        function setVoltage(this, fVoltage)
            %SETVOLTAGE Setter function for the voltage property
            
            % First we set the voltage property of the node itself
            this.fVoltage = fVoltage;
            
            % Now we loop through all of the terminals and set their
            % voltage accordingly.
            for iI = 1:this.iTerminals
                this.aoTerminals(iI).setVoltage(this.fVoltage);
            end
        end
    end
    
end

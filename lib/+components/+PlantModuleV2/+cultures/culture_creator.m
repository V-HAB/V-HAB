%% Helper to create cultures as input for the Plant Model in V HAB
% User Inputs:

% Number of Cutures
iCulture = 12;


%% CULTURE 1

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce1'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[7257600]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.0, 0.0]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

% % 
Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field111,value111);

field11 = 'Lettuce1';
value11 = {Culture1};

%% CULTURE 2

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce2'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {2};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[4233600 7862400]};

% 10. Sow Time
field123 = 'mfPlantMassInit';
value123 = {[0.7488, 0.02068]};


% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field123,value123);

field22 = 'Lettuce2';
value22 = {Culture1};

%% CULTURE 3

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce3'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[4838400]};

% 10. Sow Time
field1234 = 'mfPlantMassInit';
value1234 = {[0.3879, 0.01118]};

% 
% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field1234,value1234);

field33 = 'Lettuce3';
value33 = {Culture1};

%% CULTURE 4

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce4'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[5443200]};

% 10. Sow Time
field12345 = 'mfPlantMassInit';
value12345 = {[0.1352, 0.004531]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10, field12345,value12345);

field44 = 'Lettuce4';
value44 = {Culture1};

%% CULTURE 5

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce5'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};


% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[6048000]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.03016, 0.001768]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10, field111, value111);

field55 = 'Lettuce5';
value55 = {Culture1};

%% CULTURE 6

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Lettuce6'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.124};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {35};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[6652800]};
% 
% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.002825, 0.001049]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field111,value111);

field66 = 'Lettuce6';
value66 = {Culture1};

%% CULTURE 7

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato1'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1925};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[7257600]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.0, 0.0]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10, field111, value111);

field77 = 'Tomato1';
value77 = {Culture1};

%% CULTURE 8

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato2'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1925};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};


% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[1209600]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[1.811, 1.541]};


% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10, field111, value111);

field88 = 'Tomato2';
value88 = {Culture1};

%% CULTURE 9

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato3'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1925};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[2419200]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[1.01, 1.335]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10, field111, value111);

field99 = 'Tomato3';
value99 = {Culture1};

%% CULTURE 10

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato4'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1925};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[3628800]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.001, 1.075]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field111,value111);

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

field1010 = 'Tomato4';
value1010 = {Culture1};

%% CULTURE 11

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato5'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1925};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};


% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[4838400]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.001, 0.2867]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field111,value111);
% 
% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

field1111 = 'Tomato5';
value1111 = {Culture1};
%% CULTURE 12

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'Tomato6'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Tomato'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {0.1155};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {77};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {1};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {625};

% 8. Photoperiod
field8 = 'fH';
value8 = {12};


% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[6048000]};

% 10. Init Mass
field111 = 'mfPlantMassInit';
value111 = {[0.001, 0.02227]};

% Culture1 = struct(field1,value1,field2,value2,...
%     field3,value3,field4,value4,...
%     field6,value6,field7,value7,field8,value8,field10,value10);

Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,field10,value10,field111,value111);

field1212 = 'Tomato6';
value1212 = {Culture1};

%% CULTURE 13

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1313 = 'LettuceGenerations';
value1313 = {Culture1};


%% CULTURE 14

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1414 = 'LettuceGenerations';
value1414 = {Culture1};

%% CULTURE 15

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1515 = 'LettuceGenerations';
value1515 = {Culture1};

%% CULTURE 16

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1616 = 'LettuceGenerations';
value1616 = {Culture1};

%% CULTURE 17

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1717 = 'LettuceGenerations';
value1717 = {Culture1};

%% CULTURE 18

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1818 = 'LettuceGenerations';
value1818 = {Culture1};

%% CULTURE 19

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field1919 = 'LettuceGenerations';
value1919 = {Culture1};

%% CULTURE 20

% 1. Culture Name
field1 = 'sCultureName';
value1 = {'LettuceGenerations'};

% 2. Plant Species
field2 = 'sPlantSpecies';
value2 = {'Lettuce'};

% 3. Growth Area
field3 = 'fGrowthArea';
value3 = {1};

% 4. Harvest Time
field4 = 'fHarvestTime';
value4 = {30};

% 6. Consecutive Generations
field6 = 'iConsecutiveGenerations';
value6 = {3};

% 7. Photosynthetic Photon Flux
field7 = 'fPPFD';
value7 = {300};

% 8. Photoperiod
field8 = 'fH';
value8 = {16};

% 9. CO2 Concentration
field9 = 'fCO2';
value9 = {330};

% 10. Sow Time
field10 = 'mfSowTime';
value10 = {[0]};


Culture1 = struct(field1,value1,field2,value2,...
    field3,value3,field4,value4,...
    field6,value6,field7,value7,field8,value8,...
    field9,value9,field10,value10);

field20 = 'LettuceGenerations';
value20 = {Culture1};


%%

if iCulture == 1
    CultureInput = struct(field11,value11);
elseif iCulture == 2
    CultureInput = struct(field11,value11,field22,value22);
elseif iCulture == 3
    CultureInput = struct(field11,value11,field22,value22,field33,value33);
elseif iCulture == 4
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44);
elseif iCulture == 5
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55);
elseif iCulture == 6
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66);
elseif iCulture == 7
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77);
elseif iCulture == 8
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88);
elseif iCulture == 9
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99);
elseif iCulture == 10
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010);
elseif iCulture == 11
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111);
elseif iCulture == 12
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212);
elseif iCulture == 13
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313);
elseif iCulture == 14
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414);
elseif iCulture == 15
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515);
elseif iCulture == 16
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515,field1616,value1616);
elseif iCulture == 17
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515,field1616,value1616,field1717,value1717);
elseif iCulture == 18
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515,field1616,value1616,field1717,value1717,field1818,value1818);
elseif iCulture == 19
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515,field1616,value1616,field1717,value1717,field1818,value1818,field1919,value1919);
elseif iCulture == 20
    CultureInput = struct(field11,value11,field22,value22,field33,value33,field44,value44,field55,value55,field66,value66,field77,value77,field88,value88,field99,value99,field1010,value1010,field1111,value1111,field1212,value1212,field1313,value1313,field1414,value1414,field1515,value1515,field1616,value1616,field1717,value1717,field1818,value1818,field1919,value1919,field2020,value2020);
end

%%
%Save Culture Struct as .mat File
save('Series3Case1.mat', 'CultureInput')
clear all
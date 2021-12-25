pragma solidity ^0.5.3;

contract TaxiBusiness{

    struct Participant{
        address payable addr;
        uint account_balance;
    }

    
    struct TaxiDriver{
        address payable addr;
        uint salary;
        uint balance;
        uint lastSalaryTime;
        bool hasApproved;
        uint fireVotes;
    }

    struct Car{
        uint id;
    }

    struct DriverProposal{
        TaxiDriver driver;
        uint approves;
    }

    struct CarProposal{
        Car car;
        uint price;
        uint validTime;
        uint approves;
    }


    struct CarDealer{
        address payable addr;
        uint balance;
    }


    uint constant oneMonth=2629743;
    uint lastDividentPay;
    uint lastMaintenance;
    uint private maintenanceFee;
    uint private participationFee;
    address private manager;
    address[] public participants;
    uint private balance;
    
    
    // participant votes
    mapping(address => bool) purchaseVotes;
    mapping(address => bool) repurchaseVotes;
    mapping(address => bool) driverVotes;
    mapping(address => bool) fireVotes; 


    mapping(address => Participant) participantMapping;

    TaxiDriver taxiDriver;
    DriverProposal driverProposal;
    CarDealer carDealer;
    CarProposal purchaseCarProposal;
    CarProposal repurchaseCarProposal;
    Car businessCar;


    constructor() public { 
        manager = msg.sender;
        maintenanceFee = 10 ether;
        participationFee = 100 ether;
        balance = 0;
        lastMaintenance = block.timestamp;
        lastDividentPay = block.timestamp;
    }

    modifier checkCarDealer(){
        require(msg.sender == carDealer.addr);
        _;
    }
    
    modifier checkManager(){
        require(msg.sender == manager, "Must be manager!");
        _;
    }

    modifier checkDriver(){
        require(taxiDriver.addr != address(0), "There is no driver!");
        require(msg.sender == taxiDriver.addr, "Must be driver!");
        _;
    }


    modifier checkParticipant() {
        require(msg.sender == participantMapping[msg.sender].addr, "Must be participant!");
        _;   
    }

    function getBalance() public view returns (uint){
        return balance;
    }

    function join() public payable{
        require(participants.length < 9, "Maximum number of participants has reached!");
        require(participantMapping[msg.sender].addr == address(0), "You have already joined!");
        require(participationFee <= msg.value, "Do not have enough ether!");

        //adding to mapping for later accesses
        participantMapping[msg.sender] = Participant(
            {
                addr:msg.sender,
                account_balance:0 ether
            }
        );

        // keeping participators
        participants.push(msg.sender);


        // control overflow and update balance
        require((balance + participationFee) >= balance, "Overflow!");
        balance += participationFee;

        // if participant sends extra ether
        if(msg.value > participationFee){
            msg.sender.transfer(msg.value-participationFee);
        }

        

    }

    function carProposeToBusiness(uint _id, uint _price, uint _validTime) public checkCarDealer{
 
        require(purchaseCarProposal.car.id == 0, "The business already has a car!");

        purchaseCarProposal = CarProposal({
            car:Car(_id),
            price:_price,
            validTime:_validTime,
            approves:0
        });
    }

    function approvePurchaseCar() public checkParticipant{
        require(purchaseVotes[msg.sender] == false, "You have already voted!");
        //increment approve by one
        purchaseCarProposal.approves++;
        purchaseVotes[msg.sender] = true;

        if(purchaseCarProposal.approves > (participants.length / 2)){
            purchaseCar();
        }
    } 

    function purchaseCar() public{
        require(purchaseCarProposal.validTime <= block.timestamp, "Valid offer time passed!");
        require(balance >= purchaseCarProposal.price, "Total amount of ether is not enough to purchase");
        require(purchaseCarProposal.approves > participants.length/2, "Majority of votes not satisfied!");
        
        // decrementing balance while controlling uint underflow
        require((balance - purchaseCarProposal.price) <= balance, "Underflow!");
        balance -= purchaseCarProposal.price;
        businessCar = purchaseCarProposal.car;
        delete purchaseCarProposal;
    }


    function repurchaseCarPropose(uint _id, uint _price, uint _validTime) public checkCarDealer{
        require(businessCar.id == _id, "This car does not belong to the business!");
        
        // init repurchase car proposal 
        // set repurchase car to business car
        repurchaseCarProposal = CarProposal({
            car:businessCar,
            price:_price,
            validTime:_validTime,
            approves:0
        });
    }

    function approveSellProposal() public checkParticipant{
        require(repurchaseVotes[msg.sender] == false, "You have already voted!");
        repurchaseCarProposal.approves++;
        repurchaseVotes[msg.sender] = true;
    }


    function repurchaseCar() public payable checkCarDealer{
        require(block.timestamp <= repurchaseCarProposal.validTime, "Valid time passed!");
        require(repurchaseCarProposal.approves > (participants.length / 2), "Majority of votes not satisfied!");
        require(msg.value >= repurchaseCarProposal.price, "Do not have enough ether to complete repurchase!");

        // if dealer sends extra money, refund it
        if(msg.value > repurchaseCarProposal.price){
            msg.sender.transfer(msg.value - repurchaseCarProposal.price);
        }
        balance += repurchaseCarProposal.price;
        delete businessCar;
    }

    function proposeDriver(uint _salary) public {
        require(msg.sender != address(0), "Invalid User");
        require(taxiDriver.hasApproved == false, "The Business already has a driver!");
        driverProposal = DriverProposal(
            {
                driver: TaxiDriver({
                    addr:msg.sender,
                    salary:_salary,
                    balance:0,
                    lastSalaryTime:block.timestamp,
                    hasApproved:false,
                    fireVotes:0
                }),
                approves:0
            }
        );

    }

    function approveDriver() public checkParticipant{
        require(driverVotes[msg.sender] == false, "You have already voted!");
        driverProposal.approves++;
        driverVotes[msg.sender] = true;


        if(driverProposal.approves > (participants.length / 2)){
            setDriver();
        }
    }

    function setDriver() public {
        require(taxiDriver.addr == address(0), "The Business already has a driver!");
        require(driverProposal.driver.addr != address(0), "There is no proposed driver!");

        driverProposal.driver.hasApproved = true;
        taxiDriver = driverProposal.driver;
        delete driverProposal;
    }

    function proposeFireDriver() public checkParticipant{
        require(fireVotes[msg.sender] == false, "You have already voted!");
        fireVotes[msg.sender] = true;
        taxiDriver.fireVotes++;

        if(taxiDriver.fireVotes > (participants.length / 2)){
            fireDriver();
        }
    }   

    function fireDriver() public {
        require(taxiDriver.hasApproved == true, "There is no driver to fire!");
        // send money to driver
        taxiDriver.addr.transfer(taxiDriver.balance);

        balance -= taxiDriver.balance;
        uint salary_until_now = (block.timestamp - taxiDriver.lastSalaryTime)/oneMonth*taxiDriver.salary;
        taxiDriver.addr.transfer(salary_until_now);
        delete taxiDriver;
    }

    function leaveJob() public checkDriver{
        fireDriver();
    }

    function getCharge() payable public {
        balance += msg.value;
    }

    function getSalary() public checkDriver{
        require(taxiDriver.hasApproved == true, "There is not taxi driver!");
        require((block.timestamp - taxiDriver.lastSalaryTime) >= oneMonth, "One month not passed since last payment!");
        require(balance >= taxiDriver.salary, "Not enough balance to pay driver money!");

        balance -= taxiDriver.salary;
        taxiDriver.balance += taxiDriver.salary;
        taxiDriver.lastSalaryTime = block.timestamp;

        taxiDriver.addr.transfer(taxiDriver.balance);
    }

    function carExpenses() public payable checkParticipant {
        require(businessCar.id != 0, "There is no car to pay expense!");
        require((block.timestamp - lastMaintenance) >= (6*oneMonth), "Siz months not passed since last maintenance!");
        require(balance >= maintenanceFee, "Not enough ether to pay expense!");
        balance -= maintenanceFee;

        carDealer.addr.transfer(maintenanceFee);


        lastMaintenance = block.timestamp;
    }

    function payDividend() public checkParticipant{
        require((block.timestamp - lastDividentPay) >= 6*oneMonth, "Wait for siz months to pass!");
        require((balance - (maintenanceFee + taxiDriver.salary)) > 0, "No profit for this period!");
        uint dividend = (balance - (maintenanceFee + taxiDriver.salary)) / participants.length;
        
        // distribute money to all participants
        for(uint _i=0;_i<participants.length;_i++){
            participantMapping[participants[_i]].account_balance += dividend;
        }
        lastDividentPay = block.timestamp;
    }


    function getDividend() public checkParticipant{
        require(participantMapping[msg.sender].account_balance != 0, "No money in account!");
        participantMapping[msg.sender].addr.transfer(participantMapping[msg.sender].account_balance);
        participantMapping[msg.sender].account_balance = 0;
    }

    function setDealer(address payable _addr) public checkManager{
        carDealer = CarDealer({
            addr:_addr,
            balance:0
        });

    }
}
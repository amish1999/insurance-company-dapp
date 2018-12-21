pragma solidity ^0.4.24;

contract Ownable {
  address owner;

  modifier onlyOwnbale {
    require(msg.sender == owner);
    _;
  }
}

contract Insurance {


    event AddedBill(uint billId, string name, uint cost, bool isPayed);
    event PayedEvent(uint indexed billId);

    address owner;
    address doctor;
    uint previousState;

    struct Client {
        uint id;
        string name;
        uint franchise;
        uint count; //Decompte
        bool isReached;
    }

    struct Bill {
        uint id;
        string name;
        uint cost;
        bool isPayed;
        uint payByInsurance;
        uint payByClient;
        address to;
        address from;
    }



    //Table of balance
    mapping(address => uint) public balanceOf;
    mapping (uint => address) public clientToAddress;
    mapping (uint => address) public billToOwner;
    mapping (address => Client) public clientAccounts;
    mapping (address => uint) public clientBillCount;

    mapping (address => Bill[]) public ownerToBills;


    mapping(address => uint) public ownerClientCount;
    Client[] public clients;

    constructor(address _doctor) public payable {
        owner = msg.sender;
        doctor = _doctor;
        previousState = msg.value;
    }

    function createClient(address _address, string _name, uint _franchise) public {
        uint id = ownerClientCount[owner];
        ownerClientCount[owner]++;
        clientAccounts[_address] = Client(id, _name, _franchise, 0, false);
        clients.push(clientAccounts[_address]);
        clientToAddress[id] = _address;
    }

    function createBill(address _address, string _name, uint _cost ) private  {
        uint id = clientBillCount[_address];
        clientBillCount[_address]++;
        ownerToBills[_address].push(Bill(id, _name, _cost, false, 0, 0, _address, doctor));

        emit AddedBill(id, _name, _cost, false);
    }

    function payBill(uint _billId) public payable {

      //require that the bill belongs to the client
      require(ownerToBills[msg.sender][_billId].to == msg.sender);

      //require a valid bill
      require(_billId >= 0 && _billId <= clientBillCount[msg.sender]);

      //Verify that the bill is unpayed
      require(ownerToBills[msg.sender][_billId].isPayed == false);

      previousState = address(this).balance - msg.value;


      uint rest = (clientAccounts[msg.sender].count+ownerToBills[msg.sender][_billId].cost) - clientAccounts[msg.sender].franchise;
      uint clientToPay = ownerToBills[msg.sender][_billId].cost - rest;

      //Insurance  gives 90 % to the client address client and the client must pay 10 % for the the doctor
      if(clientAccounts[msg.sender].isReached == true)
      {
        clientAccounts[msg.sender].count += (ownerToBills[msg.sender][_billId].cost * 10) / 100;

        //Insurance transfer to client 90% of the bill cost
        (ownerToBills[msg.sender][_billId].to).transfer((ownerToBills[msg.sender][_billId].cost * 90) / 100);

        ownerToBills[msg.sender][_billId].payByClient = (ownerToBills[msg.sender][_billId].cost * 10) / 100;
        ownerToBills[msg.sender][_billId].payByInsurance = (ownerToBills[msg.sender][_billId].cost * 90) / 100;


        //Client pay to doctor 90% from insurance + 10% from himself
        doctor.transfer(msg.value);
      }

      //Insurance pay just the 90 % of the cost rest
      if((clientAccounts[msg.sender].count+ownerToBills[msg.sender][_billId].cost) >= clientAccounts[msg.sender].franchise && clientAccounts[msg.sender].isReached == false){
        clientAccounts[msg.sender].count += clientToPay + ((rest*10)/100);
        clientAccounts[msg.sender].isReached = true;

        ownerToBills[msg.sender][_billId].payByClient = clientToPay + ((rest*10)/100);
        ownerToBills[msg.sender][_billId].payByInsurance = (rest * 90) / 100;

        //Insurance transfer 90% of the rest bill to the client
        (ownerToBills[msg.sender][_billId].to).transfer((rest * 90) / 100);

        //Client pay to doctor 90% of the rest from insurance + 10% from rest himself
        doctor.transfer(msg.value);
      }

      //insurance pay nothing
      if(clientAccounts[msg.sender].count < clientAccounts[msg.sender].franchise && clientAccounts[msg.sender].count >= 0) {
        clientAccounts[msg.sender].count = clientAccounts[msg.sender].count + ownerToBills[msg.sender][_billId].cost;

        ownerToBills[msg.sender][_billId].payByClient = msg.value;
        ownerToBills[msg.sender][_billId].payByInsurance = 0;

        doctor.transfer(msg.value);
      }


      ownerToBills[msg.sender][_billId].isPayed = true;

      clients[clientAccounts[msg.sender].id] = clientAccounts[msg.sender];
      //trigger billEvent
      emit PayedEvent(_billId);
    }

    function addBill(address _address, string _name, uint _cost) public {
      createBill(_address, _name, _cost);
    }

    function getContractBalance() external view returns(uint) {
      return address(this).balance;
    }

    function getPreviousState() external view returns (uint) {
      return previousState;
    }


}

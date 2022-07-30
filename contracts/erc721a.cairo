# SPDX-License-Identifier: GPL-3.0

%lang starknet

################################################################################
################################### Library ####################################
################################################################################
from starkware.cairo.common.bool           import TRUE, FALSE
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math           import assert_not_zero, assert_not_equal, assert_in_range
from starkware.cairo.common.math_cmp       import is_not_zero
from starkware.cairo.common.uint256        import Uint256, uint256_add, uint256_sub, uint256_lt, uint256_le, uint256_check, uint256_eq, split_64
from starkware.starknet.common.syscalls    import get_caller_address, get_block_timestamp
from openzeppelin.introspection.erc165     import ERC165
from openzeppelin.introspection.IERC165    import IERC165
from openzeppelin.token.erc721.library     import IERC721_Receiver
from openzeppelin.utils.constants          import IERC721_ID, IERC721_METADATA_ID, IERC721_RECEIVER_ID, IACCOUNT_ID

################################################################################
############################### Struct variable ################################
################################################################################
struct AddressData:
    member balance: Uint256
    member numberMinted: felt
    member numberBurned: felt
    member aux: felt
end

struct TokenOwnership:
    member address: felt
    member startTimestamp: felt
    member burned: felt
end

struct BaseURIBundle:
    member low: felt  # Represent the slice of the string 'baseURI[0:31]'
    member high: felt # Represent the slice of the string 'baseURI[31:62]'
end

struct TokenURIBundle:
    member baseURI: BaseURIBundle
    member tokenId: Uint256
end

################################################################################
#################################### Event #####################################
################################################################################
@event
func Transfer(from_: felt, to: felt, tokenId: Uint256):
end

@event
func Approval(owner: felt, approved: felt, tokenId: Uint256):
end

@event
func ApprovalForAll(owner: felt, operator: felt, approved: felt):
end

################################################################################
############################### Storage variable ###############################
################################################################################
@storage_var
func _currentIndex() -> (value: Uint256):
end

@storage_var
func _burnCounter() -> (value: Uint256):
end

@storage_var
func _startTokenId() -> (value: Uint256):
end

@storage_var
func _name() -> (name: felt):
end

@storage_var
func _symbol() -> (symbol: felt):
end

@storage_var
func _baseURI() -> (baseURI: BaseURIBundle):
end

@storage_var
func _ownerships(tokenId: Uint256) -> (ownership: TokenOwnership):
end

@storage_var
func _addressData(address: felt) -> (addressData: AddressData):
end

@storage_var
func _tokenApprovals(tokenId: Uint256) -> (address: felt):
end

@storage_var
func _operatorApprovals(owner: felt, operator: felt) -> (approval: felt):
end

################################################################################
################################# Constructor ##################################
################################################################################
@constructor
func constructor{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }():
    
    # @dev
    # Remember to define the following variables before you deploy the contract.
    _name.write('')
    _symbol.write('')
    _baseURI.write(BaseURIBundle('', ''))
    
    _startTokenId.write(Uint256(0, 0))
    _currentIndex.write(Uint256(0, 0))
    
    ERC165.register_interface(IERC721_ID)
    ERC165.register_interface(IERC721_METADATA_ID)
    
    return ()
end

################################################################################
##################################### View #####################################
################################################################################
@view
func supportsInterface{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(interfaceId: felt) -> (success: felt):
    
    let (success) = ERC165.supports_interface(interfaceId)
    return (success)
end

@view
func totalSupply{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (supply: Uint256):
    
    alloc_locals
    
    let (part1: Uint256) = _currentIndex.read()
    let (part2: Uint256) = _burnCounter.read()
    let (part3: Uint256) = _startTokenId.read()
    
    let (interm: Uint256) = uint256_sub(part1, part2)
    let (output: Uint256) = uint256_sub(interm, part3)
    
    return (output)
end

@view
func balanceOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (balance: Uint256):
    
    with_attr error_message("BalanceQueryForZeroAddress"):
        assert_not_zero(owner)
    end
    
    let (addressData: AddressData) = _addressData.read(owner)
    return (addressData.balance)
end

@view
func ownerOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256) -> (address: felt):
    
    let (result: TokenOwnership) = _ownershipOf(tokenId)
    return (result.address)
end

@view
func name{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (name: felt):
    
    let (result: felt) = _name.read()
    return (result)
end

@view
func symbol{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (symbol: felt):
    
    let (result: felt) = _symbol.read()
    return (result)
end

@view
func tokenURI{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256) -> (tokenURI_: TokenURIBundle):
    
    let (baseURI: BaseURIBundle) = _baseURI.read()
    
    # tokenURI_ := string.concat(baseURI, tokenId)
    if (baseURI.low + baseURI.high) != 0:
        return (TokenURIBundle(baseURI, tokenId))
    else:
        return (TokenURIBundle(BaseURIBundle(0, 0), Uint256(0, 0)))
    end
end

@view
func getApproved{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256) -> (operator: felt):
    
    let (existence: felt) = _exists(tokenId)
    
    if existence == FALSE:
        with_attr error_mesage("ApprovalQueryForNonexistentToken"):
            assert 1 = 0
        end
        return (0)
    else:
        let (operator: felt) = _tokenApprovals.read(tokenId)
        return (operator)
    end
end

@view
func isApprovedForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, operator: felt) -> (status: felt):
    
    let (approval) = _operatorApprovals.read(owner, operator)
    return (approval)
end

################################################################################
################################### External ###################################
################################################################################
# Use OpenZeppelin implementation
@external
func approve{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, tokenId: Uint256) -> ():
    
    let (owner: felt)     = ownerOf(tokenId)
    let (msgSender: felt) = get_caller_address()
    
    with_attr error_mesage("TokenIdIsNotValidUint256"):
            uint256_check(tokenId)
    end
    
    with_attr error_message("ApprovalFromZeroAddress"):
            assert_not_zero(msgSender)
    end
    
    with_attr error_message("ApprovalToCurrentOwner"):
        assert_not_equal(owner, to)
    end
    
    if msgSender == owner:
        _approve(to, tokenId, owner)
        return ()
    else:
        let (isApproved: felt) = _operatorApprovals.read(owner, msgSender)
        
        with_attr error_message("ApprovalCallerNotOwnerNorApproved"):
            assert isApproved = TRUE
        end
        
        _approve(to, tokenId, owner)
        return ()
    end
end

@external
func setApprovalForAll{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(operator: felt, approved: felt) -> ():
    
    alloc_locals
    
    let (msgSender: felt) = get_caller_address()
    with_attr error_message("ApproveToCaller"):
        assert_not_equal(operator, msgSender)
    end
    
    with_attr error_message("ApprovedNotABoolean"):
        _assert_is_boolean(approved)
    end
    
    _operatorApprovals.write(msgSender, operator, approved)
    ApprovalForAll.emit(msgSender, operator, approved)
    return ()
end

@external
func transferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, tokenId: Uint256) -> ():
    
    _transfer(from_, to, tokenId)
    return ()
end

# Use OpenZepplin implementation
@external
func safeTransferFrom{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*) -> ():
    
    alloc_locals
    
    with_attr error_message("TokenIdIsNotValidUint256"):
        uint256_check(tokenId)
    end
    
    let (msgSender) = get_caller_address()
    let (isApproved: felt) = _isApprovedOrOwner(msgSender, tokenId)
    
    with_attr error_message("TransferCallerNotOwnerNorApproved"):
        assert_not_zero(msgSender * isApproved)
    end
    
    let (success: felt) = _checkContractOnERC721Received(from_, to, tokenId, data_len, data)
    with_attr error_message("TransferToNonERC721ReceiverImplementer"):
        assert success = TRUE
    end
    
    _transfer(from_, to, tokenId)
    return ()
end

################################################################################
################################### Internal ###################################
################################################################################
func _totalMinted{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }() -> (value: Uint256):
    
    let (part1: Uint256)  = _currentIndex.read()
    let (part2: Uint256)  = _startTokenId.read()
    let (output: Uint256) = uint256_sub(part1, part2)
    return (output)
end

func _numberMinted{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (value: felt):
    
    let (addressData: AddressData) = _addressData.read(owner)
    return (addressData.numberMinted)
end

func _numberBurned{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (value: felt):
    
    let (addressData: AddressData) = _addressData.read(owner)
    return (addressData.numberBurned)
end

func _getAux{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt) -> (value: felt):
    
    let (addressData: AddressData) = _addressData.read(owner)
    return (addressData.aux)
end

func _setAux{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, aux: felt) -> ():
    
    let (addressData: AddressData) = _addressData.read(owner)
    addressData.aux = aux    
    _addressData.write(owner, addressData)
    
    return ()
end

func _ownershipOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256) -> (ownership: TokenOwnership):
    
    alloc_locals
    
    let (startTokenId: Uint256) = _startTokenId.read()
    let (currentIndex: Uint256) = _currentIndex.read()
    let (condition1: felt) = uint256_le(startTokenId, tokenId) # TRUE(1: felt) if 1st <= 2nd
    let (condition2: felt) = uint256_lt(tokenId, currentIndex) # TRUE(1: felt) if 1st < 2nd
    
    with_attr error_message("OwnerQueryForNonexistentToken"):
        assert (condition1 * condition2) = TRUE
    end
    
    let (ownership: TokenOwnership) = _ownerships.read(tokenId)
    
    with_attr error_message("OwnerQueryForNonexistentToken"):
        assert ownership.burned = FALSE
    end
    
    if ownership.address != 0:
        return (ownership)
    # There will always be an ownership that has an address and is not burned.
    # Hence, 'curr' will never underflow. [ERC721A.sol v3.1.0 at L187-190]
    else:
        let (curr: Uint256) = uint256_sub(tokenId, Uint256(1, 0))
        return _whileOwnershipOf(curr)
    end
end

func _whileOwnershipOf{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(curr: Uint256) -> (ownership: TokenOwnership):
    
    with_attr error_mesage("TokenIdIsNotValidUint256"):
        uint256_check(curr)
    end
    
    let (ownership: TokenOwnership) = _ownerships.read(curr)    
    
    if ownership.address != 0:
        return (ownership)
    else:
        let (curr_minus_one: Uint256) = uint256_sub(curr, Uint256(1, 0))
        return _whileOwnershipOf(curr_minus_one)
    end
end

func _approve{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, tokenId: Uint256, owner: felt) -> ():
    
    _tokenApprovals.write(tokenId, to)
    Approval.emit(owner, to, tokenId)
    return ()
end

func _exists{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256) -> (status: felt):
    
    alloc_locals
    
    # Condition 1: 'tokenId' must be larger than or equal to '_startTokenId'
    let (startTokenId: Uint256) = _startTokenId.read()
    let (condition1: felt) = uint256_lt(tokenId, startTokenId)
    if condition1 == TRUE:
        return (FALSE)
    end
    
    # Condition 2: 'tokenId' must be smaller than '_currentIndex'
    let (currentIndex: Uint256) = _currentIndex.read()
    let (condition2: felt) = uint256_le(currentIndex, tokenId)
    if condition2 == TRUE:
        return (FALSE)
    end
    
    # Condition 3: Token must be not burned
    let (ownership: TokenOwnership) = _ownershipOf(tokenId)
    if ownership.burned == TRUE:
        return (FALSE)
    else:
        return(TRUE)
    end
end

func _transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, tokenId: Uint256) -> ():
    
    alloc_locals
    
    let (prevOwnership: TokenOwnership) = _ownershipOf(tokenId)
    let (msgSender: felt)               = get_caller_address()
    let (approvalAddress: felt)         = getApproved(tokenId)
    
    with_attr error_mesage("TransferFromIncorrectOwner"):
        assert prevOwnership.address = from_
    end
    
    let (isApprovedOrOwner: felt) = _isApprovedOrOwner(msgSender, tokenId)
    with_attr error_mesage("TransferCallerNotOwnerNorApproved"):
        assert_not_zero(msgSender * isApprovedOrOwner)
    end
    
    with_attr error_mesage("TransferToZeroAddress"):
        assert_not_zero(to)
    end
    
    _beforeTokenTransfers(from_, to, tokenId, 1)
    _approve(0, tokenId, from_)
    
    # Core snippet: The 'unchecked{}' part of codes in the ERC721A.sol
    let (prevFromAddrData: AddressData) = _addressData.read(from_)
    let (currFromBalance: Uint256) = uint256_sub(prevFromAddrData.balance, Uint256(1, 0))
    let currFromAddrData = AddressData(
        currFromBalance, 
        prevFromAddrData.numberMinted, 
        prevFromAddrData.numberBurned, 
        prevFromAddrData.aux
    )
    _addressData.write(from_, currFromAddrData)
    
    let (prevToAddrData: AddressData) = _addressData.read(to)
    let (currToBalance: Uint256, _) = uint256_add(prevToAddrData.balance, Uint256(1, 0))
    let currToAddrData = AddressData(
        currToBalance, 
        prevToAddrData.numberMinted, 
        prevToAddrData.numberBurned, 
        prevToAddrData.aux
    )
    _addressData.write(to, currToAddrData)
    
    let (oldCurrSlot: TokenOwnership) = _ownerships.read(tokenId)
    let (newStartTimestamp: felt) = get_block_timestamp()
    let newCurrSlot = TokenOwnership(
        to, 
        newStartTimestamp, 
        oldCurrSlot.burned
    )
    _ownerships.write(tokenId, newCurrSlot)
    
    let (nextTokenId: Uint256, _) = uint256_add(tokenId, Uint256(1, 0))
    let (oldNextSlot: TokenOwnership) = _ownerships.read(nextTokenId)
    let newNextSlot = TokenOwnership(
        from_, 
        prevOwnership.startTimestamp,
        oldNextSlot.burned
    )
    let (currentIndex: Uint256) = _currentIndex.read()
    let (condition: felt) = uint256_eq(nextTokenId, currentIndex)
    
    if oldNextSlot.address == 0:
        if condition == FALSE:
            _ownerships.write(tokenId, newNextSlot)
            Transfer.emit(from_, to, tokenId)
            _afterTokenTransfers(from_, to, tokenId, 1)
            return ()
        else:
            Transfer.emit(from_, to, tokenId)
            _afterTokenTransfers(from_, to, tokenId, 1)
            return ()
        end        
    else:
        Transfer.emit(from_, to, tokenId)
        _afterTokenTransfers(from_, to, tokenId, 1)
        return ()
    end
end

func _is_zero{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(value: felt) -> (result: felt):
    
    if value == 0:
        return (result=TRUE)
    else:
        return (result=FALSE)
    end
end

func _assert_is_boolean{range_check_ptr}(value: felt) -> ():
    assert_in_range(value, 0, 2) # Check 'value' is in the set {0, 1}
    return ()
end

func _beforeTokenTransfers{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, startTokenId: Uint256, quantity: felt) -> ():
    return ()
end

func _afterTokenTransfers{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, startTokenId: Uint256, quantity: felt) -> ():
    return ()
end

# Cairo-lang has not supported function overloading yet.
# The implementation does not include '_burn(uint256 tokenId)'

func _isApprovedOrOwner{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(spender: felt, tokenId: Uint256) -> (status: felt):
    
    alloc_locals
    
    let (existence) = _exists(tokenId)
    with_attr error_message("ApprovalQueryForNonexistentToken"):
        assert existence = TRUE
    end
    
    let (owner: TokenOwnership) = _ownershipOf(tokenId)
    if owner.address == spender:
        return (TRUE)
    end
    
    let (approvedAddress) = getApproved(tokenId)
    if approvedAddress == spender:
        return (TRUE)
    end
    
    let (isOperator) = isApprovedForAll(owner.address, spender)
    if isOperator == TRUE:
        return (TRUE)
    else:
        return(FALSE)
    end
end

func _checkContractOnERC721Received{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(from_: felt, to: felt, tokenId: Uint256, data_len: felt, data: felt*) -> (success: felt):
    
    let (msgSender) = get_caller_address()
    let (isSupported) = IERC165.supportsInterface(to, IERC721_RECEIVER_ID)
    
    if isSupported == TRUE:
        let (selector: felt) = IERC721_Receiver.onERC721Received(to, msgSender, from_, tokenId, data_len, data)
        
        with_attr error_message("TransferToNonERC721ReceiverImplementer"):
            assert selector = IERC721_RECEIVER_ID
        end
        
        return (TRUE)
    else:
        let (isAccount) = IERC165.supportsInterface(to, IACCOUNT_ID) # TRUE(1: felt) if the address is an "account" contract
        return (isAccount)
    end
end

func _safeMint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, quantity: felt, data_len: felt, data: felt*) -> ():
    
    _mint(to, quantity, data_len, data, TRUE)
    return ()
end

func _mint{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, quantity: felt, data_len: felt, data: felt*, safe: felt) -> ():
    
    alloc_locals
    
    with_attr error_message("MintToZeroAddress"):
        let (result: felt) = is_not_zero(to)
        assert result = TRUE
    end
    
    with_attr error_message("MintZeroQuantity"):
        let (result: felt) = is_not_zero(quantity)
        assert result = TRUE
    end
    
    with_attr error_message("SafeNotABoolean"):
        _assert_is_boolean(safe)
    end
    
    let (startTokenId: Uint256) = _currentIndex.read()
    
    _beforeTokenTransfers(0, to, startTokenId, quantity)
    
    # Core snippet: The 'unchecked{}' part of codes in the ERC721A.sol
    let (prevToAddrData: AddressData) = _addressData.read(to)
    
    let (quantityLo: felt, quantityHi: felt) = split_64(quantity)
    let quantityUint256 = Uint256(quantityLo, quantityHi)
    let (currToBalance: Uint256, _) = uint256_add(prevToAddrData.balance, quantityUint256)
    
    let currToNumMinted = prevToAddrData.numberMinted + quantity
    let currToAddrData = AddressData(
        currToBalance,
        currToNumMinted,
        prevToAddrData.numberBurned,
        prevToAddrData.aux
    )
    
    let (newStartTimestamp: felt) = get_block_timestamp()
    let newCurrSlot = TokenOwnership(
        to, 
        newStartTimestamp, 
        FALSE
    )
    _ownerships.write(startTokenId, newCurrSlot)
    
    let updatedIndex = startTokenId
    let (endIndex: Uint256, _) = uint256_add(updatedIndex, quantityUint256)
    
    let condition1 = safe
    let (condition2: felt) = IERC165.supportsInterface(to, IACCOUNT_ID)
    if (condition1 * condition2) == TRUE:
        Transfer.emit(0, to, updatedIndex)
        
        let (success: felt) = _checkContractOnERC721Received(0, to, updatedIndex, data_len, data)
        with_attr error_message("TransferToNonERC721ReceiverImplementer"):
            assert success = TRUE
        end
        
        let (updatedIndexPlusOne: Uint256, _) = uint256_add(updatedIndex, Uint256(1, 0))
        _whileMintIfPart(to, updatedIndexPlusOne, endIndex, data_len, data)
        
        _afterTokenTransfers(0, to, startTokenId, quantity)
        return ()
    else:
        Transfer.emit(0, to, updatedIndex)
        
        let (updatedIndexPlusOne: Uint256, _) = uint256_add(updatedIndex, Uint256(1, 0))
        _whileMintElsePart(to, updatedIndexPlusOne, endIndex)
        
        _afterTokenTransfers(0, to, startTokenId, quantity)
        return ()
    end
end

func _whileMintIfPart{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, updatedIndex: Uint256, endIndex: Uint256, data_len: felt, data: felt*) -> ():
    
    let (status: felt) = uint256_eq(updatedIndex, endIndex)
    
    if status == FALSE:
        Transfer.emit(0, to, updatedIndex)
        
        let (success: felt) = _checkContractOnERC721Received(0, to, updatedIndex, data_len, data)
        with_attr error_message("TransferToNonERC721ReceiverImplementer"):
            assert success = TRUE
        end
        
        let (updatedIndexPlusOne: Uint256, _) = uint256_add(updatedIndex, Uint256(1, 0))
        _whileMintIfPart(to, updatedIndexPlusOne, endIndex, data_len, data)
        
        return ()
    else:
        return ()
    end
end

func _whileMintElsePart{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(to: felt, updatedIndex: Uint256, endIndex: Uint256) -> ():
    
    let (status: felt) = uint256_eq(updatedIndex, endIndex)
    
    if status == FALSE:
        Transfer.emit(0, to, updatedIndex)
        
        let (updatedIndexPlusOne: Uint256, _) = uint256_add(updatedIndex, Uint256(1, 0))
        _whileMintElsePart(to, updatedIndexPlusOne, endIndex)
        
        return ()
    else:
        return ()
    end
end

func _burn{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(tokenId: Uint256, approvalCheck: felt) -> ():
    
    alloc_locals
    
    with_attr error_message("ApprovedCheckNotABoolean"):
        _assert_is_boolean(approvalCheck)
    end
    
    let (prevOwnership: TokenOwnership) = _ownershipOf(tokenId)
    let from_ = prevOwnership.address
    
    let (success: felt) = _approvalCheck(from_, tokenId)
    with_attr error_message("TransferCallerNotOwnerNorApproved"):
        assert success = TRUE
    end
    
    _beforeTokenTransfers(from_, 0, tokenId, 1)
    
    _approve(0, tokenId, from_)
    
    # Core snippet: The 'unchecked{}' part of codes in the ERC721A.sol
    let (oldAddressData: AddressData) = _addressData.read(from_)
    let (newAddressDataBalance: Uint256) = uint256_sub(oldAddressData.balance, Uint256(1, 0))
    let newAddressData = AddressData(
        newAddressDataBalance, 
        oldAddressData.numberMinted, 
        oldAddressData.numberBurned + 1, 
        oldAddressData.aux
    )
    _addressData.write(from_, newAddressData)
    
    let (oldCurrSlot: TokenOwnership) = _ownerships.read(tokenId)
    let (newStartTimestamp: felt) = get_block_timestamp()
    let newCurrSlot = TokenOwnership(
        from_, 
        newStartTimestamp, 
        TRUE
    )
    _ownerships.write(tokenId, newCurrSlot)
    
    let (nextTokenId: Uint256, _) = uint256_add(tokenId, Uint256(1, 0))
    let (oldNextSlot: TokenOwnership) = _ownerships.read(nextTokenId)
    let newNextSlot = TokenOwnership(
        from_, 
        prevOwnership.startTimestamp,
        oldNextSlot.burned
    )
    let (currentIndex: Uint256) = _currentIndex.read()
    let (condition: felt) = uint256_eq(nextTokenId, currentIndex)
    
    if oldNextSlot.address == 0:
        if condition == FALSE:
            _ownerships.write(tokenId, newNextSlot)
            
            Transfer.emit(from_, 0, tokenId)
            _afterTokenTransfers(from_, 0, tokenId, 1)
            
            let (oldBurnCounter: Uint256) = _burnCounter.read()
            let (newBurnCounter: Uint256, _) = uint256_add(oldBurnCounter, Uint256(1, 0))
            _burnCounter.write(newBurnCounter)
            return ()
        else:
            Transfer.emit(from_, 0, tokenId)
            _afterTokenTransfers(from_, 0, tokenId, 1)
            
            let (oldBurnCounter: Uint256) = _burnCounter.read()
            let (newBurnCounter: Uint256, _) = uint256_add(oldBurnCounter, Uint256(1, 0))
            _burnCounter.write(newBurnCounter)
            return ()
        end
    else:
        Transfer.emit(from_, 0, tokenId)
        _afterTokenTransfers(from_, 0, tokenId, 1)
        
        let (oldBurnCounter: Uint256) = _burnCounter.read()
        let (newBurnCounter: Uint256, _) = uint256_add(oldBurnCounter, Uint256(1, 0))
        _burnCounter.write(newBurnCounter)
        return ()
    end
end

func _approvalCheck{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
    }(owner: felt, tokenId: Uint256) -> (success: felt):
    
    alloc_locals
    
    let (msgSender: felt) = get_caller_address()
    let (operator: felt) = getApproved(tokenId)
    
    let (condition1: felt)  = _is_zero(msgSender - owner)
    let (condition2: felt)  = isApprovedForAll(owner, msgSender)
    let (condition3: felt)  = _is_zero(operator - msgSender)
    
    if (condition1 + condition2 + condition3) != 0:
        return (TRUE)
    else:
        return (FALSE)
    end
end
use uefi::prelude::*;
use core::ptr::NonNull;
use x86_64::{
    registers::{control::*, model_specific::*},
    structures::{gdt::*, paging::*, descriptor_table::*},
    VirtAddr,
};
use lazy_static::lazy_static;
use spin::Mutex;

/// Initializes the core x86_64 architecture components
pub fn init() -> Status {
    // Initialize core CPU features
    gdt::init();
    idt::init();
    
    // Enable required CPU features
    unsafe {
        enable_nxe_bit();
        enable_write_protect_bit();
    }
    
    // Set up memory management
    memory::init()?;
    
    Status::SUCCESS
}

/// Initialize x86_64 features
unsafe fn enable_nxe_bit() {
    let efer = Efer::read();
    Efer::write(efer | EferFlags::NO_EXECUTE_ENABLE);
}

unsafe fn enable_write_protect_bit() {
    Cr0::write(Cr0::read() | Cr0Flags::WRITE_PROTECT);
}

lazy_static! {
    static ref TSS: TaskStateSegment = {
        let mut tss = TaskStateSegment::new();
        tss.interrupt_stack_table[DOUBLE_FAULT_IST_INDEX] = {
            const STACK_SIZE: usize = 4096 * 5;
            static mut STACK: [u8; STACK_SIZE] = [0; STACK_SIZE];
            let stack_start = VirtAddr::from_ptr(unsafe { &STACK });
            let stack_end = stack_start + STACK_SIZE;
            stack_end
        };
        tss
    };
}

pub const DOUBLE_FAULT_IST_INDEX: u16 = 0;

lazy_static! {
    static ref GDT: (GlobalDescriptorTable, Selectors) = {
        let mut gdt = GlobalDescriptorTable::new();
        let code_selector = gdt.add_entry(Descriptor::kernel_code_segment());
        let data_selector = gdt.add_entry(Descriptor::kernel_data_segment());
        let tss_selector = gdt.add_entry(Descriptor::tss_segment(&TSS));
        (gdt, Selectors { code_selector, data_selector, tss_selector })
    };
}

struct Selectors {
    code_selector: SegmentSelector,
    data_selector: SegmentSelector,
    tss_selector: SegmentSelector,
}

/// Initialize the Global Descriptor Table
pub fn gdt_init() {
    GDT.0.load();
    unsafe {
        CS::set_reg(GDT.1.code_selector);
        DS::set_reg(GDT.1.data_selector);
        SS::set_reg(GDT.1.data_selector);
        load_tss(GDT.1.tss_selector);
    }
}

/// Hardware-specific initialization
pub fn hardware_init() -> Status {
    // Initialize CPU features
    apic::init()?;
    hpet::init()?;
    
    // Initialize device controllers
    pci::init()?;
    
    Status::SUCCESS
}

pub mod syscall;
